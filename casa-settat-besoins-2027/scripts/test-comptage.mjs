import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { inflateRawSync } from 'node:zlib';
import { COUNT_FIELDS, COUNT_GROUPS, countFingerprint, countRowsToDraft, countTotals, monthDates, templateDates, validateCountSubmission } from '../lib/comptage.mjs';
import { countAgencyAndRoute, exportCountWorkbook, fillCountWorksheet } from '../lib/comptage-excel.mjs';
import { conciseCountWorkbook } from '../lib/count-excel-client.mjs';
import { zipStored } from '../lib/excel.mjs';

const root=path.resolve(import.meta.dirname,'..');
const template=JSON.parse(await fs.readFile(path.join(root,'lib/comptage-template.json'),'utf8'));
assert.equal(COUNT_FIELDS.length,14);assert.equal(COUNT_GROUPS.reduce((sum,group)=>sum+group.count,0),14);
assert.equal(templateDates('2026-11').length,19);
assert.deepEqual(templateDates('2026-11').map(date=>Number(date.slice(8))),[2,3,4,5,9,10,11,12,13,16,17,19,20,23,24,25,26,27,30]);
assert.equal(monthDates('2028-02').length,29);assert.equal(monthDates('2027-02').length,28);
const values=(first,last)=>[first,0,...Array(11).fill(null),last];
const first=validateCountSubmission({agency:'Agence Settat & Centre',month:'2026-11',rows:[{date:'2026-11-02',frequency:5,values:values(12,3)},{date:'2026-11-30',frequency:2,values:values(4,7)}]});
assert.equal(first.rows[0].values[1],0,'A declared zero must remain different from an empty cell');
assert.equal(first.rows[0].values[2],null);
assert.deepEqual(countTotals(first.rows),[16,0,...Array(11).fill(0),10]);
for(const row of [
 {date:'2026-11-31',frequency:5,values:values(1,0)},
 {date:'2026-12-01',frequency:5,values:values(1,0)},
 {date:'2026-11-02',frequency:null,values:values(1,0)},
 {date:'2026-11-02',frequency:6,values:values(1,0)},
 {date:'2026-11-02',frequency:5,values:values(-1,0)},
 {date:'2026-11-02',frequency:5,values:values(1.5,0)},
 {date:'2026-11-02',frequency:5,values:[1]},
])assert.throws(()=>validateCountSubmission({agency:'Agence A',month:'2026-11',rows:[row]}));
assert.throws(()=>validateCountSubmission({agency:'Agence A',month:'2026-11',rows:[first.rows[0],first.rows[0]]}));
const draft=countRowsToDraft(first.rows), padded=structuredClone(draft);padded['2026-11-02'].values[0]='0012';
assert.equal(countFingerprint(first.agency,first.month,draft),countFingerprint(first.agency,first.month,padded));
assert.notEqual(countFingerprint(first.agency,'2026-12',draft),countFingerprint(first.agency,first.month,draft));
const raw=template.find(entry=>entry.name==='xl/worksheets/sheet1.xml');
const source=inflateRawSync(Buffer.from(raw.base64,'base64')).toString();
const sheet=fillCountWorksheet(source,first);
assert.match(sheet,/<x:c r="C24"[^>]*><x:f>SUM\(C5:C23\)<\/x:f><x:v>16<\/x:v>/);
assert.match(sheet,/<x:c r="P24"[^>]*><x:f>SUM\(P5:P23\)<\/x:f><x:v>10<\/x:v>/);
assert.match(sheet,/<x:c r="D5"[^>]*><x:v>0<\/x:v>/);
assert.match(sheet,/<x:c r="E5"[^>]*\/>/);
assert.match(sheet,/Agence Settat &amp; Centre/);
assert.match(sheet,/<x:c r="A5"[^>]*t="d"><x:v>2026-11-02T00:00:00.000Z/);
assert.match(sheet,/<x:t[^>]*>5\/5<\/x:t>/);
const header=xml=>xml.match(/<x:row r="3"[\s\S]*?<x:row r="5"/)[0];
assert.equal(header(sheet),header(source),'The photographed canvas headers must remain unchanged');
const special=fillCountWorksheet(source,{...first,rows:[...first.rows,{date:'2026-11-07',frequency:1,values:values(1,0)}]});
assert.match(special,/SUM\(C5:C24\)/);assert.match(special,/<x:c r="C25"[^>]*>[\s\S]*?<x:v>17<\/x:v>/);
const tourneeOne={...first,agency:'Agence Settat & Centre — tournée de distribution 1'};
const tourneeTen={...first,agency:'Agence Settat & Centre — tournée de distribution 10'};
assert.deepEqual(countAgencyAndRoute(tourneeOne.agency),{agency:'Agence Settat & Centre',tournee:1});
assert.deepEqual(countAgencyAndRoute(tourneeTen.agency),{agency:'Agence Settat & Centre',tournee:10});
assert.equal(countAgencyAndRoute(first.agency).tournee,null);
const tourneeSheet=fillCountWorksheet(source,tourneeOne);
assert.match(tourneeSheet,/Agence Settat &amp; Centre T1/);
assert.match(tourneeSheet,/Tournée N°: 1/);
const label=fillCountWorksheet(source,{...tourneeOne,agency:'AZEMMOUR — tournée de distribution 1'});
assert.match(label,/AZEMMOUR T1/);
assert.doesNotMatch(label,/AZEMMOUR — tournée de distribution 1/);
const startTitle=source.indexOf('<x:c r="A1"');
const endTitle=source.indexOf('</x:c>',startTitle)+6;
assert.ok(startTitle>=0 && endTitle>startTitle,'The Excel template must contain a title cell');
const oldTitle=source.slice(0,startTitle)
  + '<x:c r="A1" s="1" t="inlineStr"><x:is><x:t>AZEMMOUR — tournée de distribution 1</x:t></x:is></x:c>'
  + source.slice(endTitle);
const oldDownload=zipStored([
  {name:'xl/worksheets/sheet1.xml',data:new TextEncoder().encode(oldTitle)},
  {name:'xl/workbook.xml',data:new TextEncoder().encode('<x:workbook><x:sheets><x:sheet name="AZEMMOUR — tournée de distribut" sheetId="1"/></x:sheets></x:workbook>')},
]);
const amended=Buffer.from(await (await conciseCountWorkbook(
  new Blob([oldDownload],{type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}),
  [{agency:'AZEMMOUR — tournée de distribution 1'}]
)).arrayBuffer());
assert.ok(amended.includes(Buffer.from('AZEMMOUR T1')),'Browser download must show the short agency + route label');
assert.ok(!amended.includes(Buffer.from('AZEMMOUR — tournée de distribut')),'Long route label must not appear in downloadable ZIP');
const second={...first,agency:'Agence Settat / Centre',rows:[{date:'2026-11-02',frequency:1,values:values(2,1)}]};
const bytes=exportCountWorkbook(template,[first,second,tourneeOne,tourneeTen]);
assert.ok(bytes.length>10000);
await fs.mkdir(path.join(root,'outputs'),{recursive:true});
await fs.writeFile(path.join(root,'outputs/comptage-sample.xlsx'),bytes);
assert.ok(bytes.length>10000);
console.log('PASS: 14 colonnes, 19 dates du canevas, validation, zéro/absence, totaux distincts, calendrier, formules, dates Excel et export multi-agences.');
