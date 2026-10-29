import { zipStored } from './excel.mjs';

const encoder = new TextEncoder();
const xml = text => String(text??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&apos;').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g,'');
const excelText = text => {
 // Disable Excel formula evaluation on imported CAB, agency names and remarks.
 const value = String(text??'');
 return /^[=+\-@]/.test(value) ? "'"+value : value;
};
function col(n){let s='';for(let i=n+1;i>0;i=Math.floor((i-1)/26))s=String.fromCharCode(65+(i-1)%26)+s;return s}
const cell=(v,r,c,header=false)=>{
 const val=excelText(v);
 return '<c r="'+col(c)+r+'" t="inlineStr" s="'+(header?1:0)+'"><is><t xml:space="preserve">'+xml(val)+'</t></is></c>';
};
const titles=[
 ['Synthèse', ['Opération','Agence','Total CAB','Bouclés','Déjà notifiés','Restants','Anomalies','Dernière consultation','Dernier agent']],
 ['Bouclage AM', ['Agence','CAB','Statut','Observation','Agent du contrôle','Date du contrôle','Fichier source','Réimports','Présence dernier fichier']],
 ['Notif. enregistrés', ['Agence','CAB','Statut','Observation','Agent du contrôle','Date du contrôle','Fichier source','Réimports','Présence dernier fichier']],
 ['Notif. recommandés', ['Agence','CAB','Statut','Observation','Agent du contrôle','Date du contrôle','Fichier source','Réimports','Présence dernier fichier']],
 ['HDG', ['Agence','CAB','Statut','Observation','Agent du contrôle','Date du contrôle','Fichier source','Réimports','Présence dernier fichier']],
 ['Consultations', ['Opération','Agence','Identifiant connecté','Nom déclaré de l’agent','Date / heure','CAB visibles']]
];
function sheetXml(headers,rows){
 let sheet='<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"/></sheetViews><sheetFormatPr defaultRowHeight="16"/><cols>';
 for(let i=0;i<headers.length;i++)sheet+='<col min="'+(i+1)+'" max="'+(i+1)+'" width="'+(i===3?35:22)+'" customWidth="1"/>';
 sheet+='</cols><sheetData>';
 const push=(arr,idx,header=false)=>{sheet+='<row r="'+idx+'">';for(let i=0;i<arr.length;i++)sheet+=cell(arr[i],idx,i,header);sheet+='</row>'};
 push(headers,1,true);
 for(let i=0;i<rows.length;i++)push(rows[i],i+2);
 return sheet+'</sheetData><autoFilter ref="A1:'+col(headers.length-1)+(rows.length+1)+'"/></worksheet>';
}
export function createControleWorkbook(sheets){
 const entries=[
 {name:'[Content_Types].xml',data:encoder.encode('<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'+titles.map((_,i)=>'<Override PartName="/xl/worksheets/sheet'+(i+1)+'.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join('')+'</Types>')},
 {name:'_rels/.rels',data:encoder.encode('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')},
 {name:'xl/workbook.xml',data:encoder.encode('<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'+titles.map(([title],i)=>'<sheet name="'+xml(title)+'" sheetId="'+(i+1)+'" r:id="rId'+(i+1)+'"/>').join('')+'</sheets></workbook>')},
 {name:'xl/_rels/workbook.xml.rels',data:encoder.encode('<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'+titles.map((_,i)=>'<Relationship Id="rId'+(i+1)+'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet'+(i+1)+'.xml"/>').join('')+'<Relationship Id="rId7" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>')},
 {name:'xl/styles.xml',data:encoder.encode('<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Aptos"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Aptos"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1D4E72"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/></cellXfs></styleSheet>')}
 ];
 titles.forEach(([_,header],i)=>entries.push({name:'xl/worksheets/sheet'+(i+1)+'.xml',data:encoder.encode(sheetXml(header,sheets[i]||[]))}));
 return zipStored(entries);
}
