import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { exportWorkbook, consolidate, fillWorksheet } from '../lib/excel.mjs';
import { validateSubmission, agencyKey } from '../lib/validation.mjs';
import { inflateRawSync } from 'node:zlib';

const catalog = JSON.parse(await fs.readFile(new URL('../lib/catalog.json', import.meta.url), 'utf8'));
const template = JSON.parse(await fs.readFile(new URL('../lib/excel-template.json', import.meta.url), 'utf8'));
assert.equal(catalog.items.length, 175);
assert.deepEqual(catalog.sheets.map(sheet => catalog.items.filter(item => item.sheet === sheet.id).length), [12, 163]);
const responses = [
  validateSubmission({ agency: 'Agence Settat', items: [{ id: 's1-r10', quantity: 3, comment: 'Remplacer les claviers <HS> & anciens' }, { id: 's2-r24', quantity: 1.25, comment: 'Ficelle en kg' }, { id: 's2-r172', quantity: 2, comment: '=HYPERLINK("test")' }] }, catalog.items),
  validateSubmission({ agency: 'Agence Casablanca', items: [{ id: 's1-r10', quantity: 2, comment: 'Nouveaux postes' }, { id: 's2-r24', quantity: 0.5, comment: '' }] }, catalog.items),
];
const totals = consolidate(responses, catalog);
assert.equal(totals.get('s1-r10').quantity, 500);
assert.equal(totals.get('s2-r24').quantity, 175);
assert.equal(totals.get('s2-r172').quantity, 200);
assert.equal(totals.get('s1-r11').comments.length, 0);
assert.equal(agencyKey(' Agence  SÉTTAT '), agencyKey('agence-settat'));
for (const badQuantity of [0, -1, NaN, Infinity, 0.001, 100001, '3']) {
  assert.throws(() => validateSubmission({ agency: 'Agence Settat', items: [{ id: 's1-r10', quantity: badQuantity }] }, catalog.items));
}
for (const badItems of [[], [{ id: 's1-r999', quantity: 1 }], [{ id: 's1-r10', quantity: 1 }, { id: 's1-r10', quantity: 2 }]]) {
  assert.throws(() => validateSubmission({ agency: 'Agence Settat', items: badItems }, catalog.items));
}
assert.throws(() => validateSubmission({ agency: ' ', items: [{ id: 's1-r10', quantity: 1 }] }, catalog.items));
assert.throws(() => validateSubmission({ agency: 'Agence Settat', items: [{ id: 's1-r10', quantity: 1, comment: 'a'.repeat(1501) }] }, catalog.items));

function original(entry) { const raw = Buffer.from(entry.base64, 'base64'); return (entry.method === 8 ? inflateRawSync(raw) : raw).toString('utf8'); }
for (const sheet of catalog.sheets) {
  const xml = original(template.find(entry => entry.name === sheet.path));
  const edited = fillWorksheet(xml, sheet, catalog, totals);
  // Compare every cell except the explicitly allowed quantity/comment inputs.
  const cellMap = text => new Map([...text.matchAll(/<c\b[^>]*\br="([A-Z]+[0-9]+)"[^>]*?(?:\s*\/>|>[\s\S]*?<\/c>)/g)].map(match => [match[1], match[0]]));
  const before = cellMap(xml), after = cellMap(edited);
  assert.equal(after.size, before.size);
  const changed = [];
  for (const [ref, content] of before) {
    if (content !== after.get(ref)) {
      assert.ok(catalog.items.some(item => item.sheet === sheet.id && [sheet.quantityColumn + item.row, sheet.commentColumn + item.row].includes(ref)), 'Unexpected edit to ' + ref);
      changed.push(ref);
    }
  }
  assert.equal(changed.length, sheet.id === 1 ? 2 : 4);
  if (sheet.id === 1) {
    assert.match(edited, /<c[^>]*r="H10"[^>]*><v>5<\/v><\/c>/);
    assert.match(edited, /Agence Settat : 3 — Remplacer les claviers &lt;HS&gt; &amp; anciens\nAgence Casablanca : 2 — Nouveaux postes/);
  } else {
    assert.match(edited, /<c[^>]*r="F24"[^>]*><v>1.75<\/v><\/c>/);
    assert.match(edited, /r="I172"[^>]*t="inlineStr"/);
    assert.ok(!edited.includes('<f>HYPERLINK'));
  }
}
const bytes = exportWorkbook(template, catalog, responses);
assert.equal(new DataView(bytes.buffer).getUint32(0, true), 0x04034b50);
await fs.mkdir(new URL('../outputs/', import.meta.url), { recursive: true });
await fs.writeFile(new URL('../outputs/test-consolidation.xlsx', import.meta.url), bytes);
console.log('PASS: 175 articles, validation, consolidation multi-agences, décimales, texte sûr et préservation des autres cellules.');
