import { inflateRawSync } from 'node:zlib';

// Fill the two input columns in the supplied OOXML template. All other ZIP
// members and cell attributes remain unchanged. No formulas are evaluated.
const encoder = new TextEncoder();
const decoder = new TextDecoder();
const xmlEscape = value => String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');

export function consolidate(responses, catalog) {
  const totals = new Map(catalog.items.map(item => [item.id, { quantity: 0, comments: [] }]));
  for (const response of responses) {
    for (const item of response.items) {
      const target = totals.get(item.id);
      if (!target) throw new Error('Un article enregistré ne correspond pas au modèle Excel.');
      target.quantity += Math.round(item.quantity * 100);
      const qty = new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 }).format(item.quantity);
      target.comments.push(`${response.agency} : ${qty}${item.comment ? ' — ' + item.comment : ''}`);
    }
  }
  return totals;
}

function replaceCell(xml, ref, value, isNumber) {
  const expression = new RegExp('<c\\b([^>]*\\br="' + ref + '"[^>]*?)(?:\\s*/>|>[\\s\\S]*?</c>)');
  let found = false;
  const result = xml.replace(expression, (_all, attributes) => {
    found = true;
    const attrs = attributes.replace(/\s+t="[^"]*"/g, '').replace(/\s*\/$/, '');
    return isNumber ? `<c${attrs}><v>${value}</v></c>` : `<c${attrs} t="inlineStr"><is><t xml:space="preserve">${xmlEscape(value)}</t></is></c>`;
  });
  if (!found) throw new Error(`La cellule ${ref} est introuvable dans le modèle.`);
  return result;
}

export function fillWorksheet(xml, sheet, catalog, totals) {
  for (const item of catalog.items.filter(item => item.sheet === sheet.id)) {
    const total = totals.get(item.id);
    if (!total?.comments.length) continue;
    const comment = total.comments.join('\n');
    if (comment.length > 32767) throw new Error(`Le commentaire de « ${item.label} » dépasse la limite Excel. Exportez les agences séparément.`);
    xml = replaceCell(xml, sheet.quantityColumn + item.row, total.quantity / 100, true);
    xml = replaceCell(xml, sheet.commentColumn + item.row, comment, false);
  }
  return xml;
}

const crcTable = Array.from({ length: 256 }, (_, value) => {
  let crc = value;
  for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  return crc >>> 0;
});
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = (crc >>> 8) ^ crcTable[(crc ^ byte) & 255];
  return (crc ^ 0xffffffff) >>> 0;
}
function concat(arrays) {
  const result = new Uint8Array(arrays.reduce((sum, item) => sum + item.length, 0));
  let offset = 0;
  for (const array of arrays) { result.set(array, offset); offset += array.length; }
  return result;
}
function zipStored(entries) {
  const locals = [], directory = [];
  let offset = 0;
  for (const entry of entries) {
    const name = encoder.encode(entry.name), data = entry.data, crc = crc32(data);
    const header = new Uint8Array(30 + name.length), h = new DataView(header.buffer);
    h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint16(6, 0x800, true);
    h.setUint16(12, 0x21, true); h.setUint32(14, crc, true); h.setUint32(18, data.length, true); h.setUint32(22, data.length, true); h.setUint16(26, name.length, true);
    header.set(name, 30); locals.push(header, data);
    const central = new Uint8Array(46 + name.length), c = new DataView(central.buffer);
    c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true); c.setUint16(8, 0x800, true); c.setUint16(14, 0x21, true);
    c.setUint32(16, crc, true); c.setUint32(20, data.length, true); c.setUint32(24, data.length, true); c.setUint16(28, name.length, true); c.setUint32(42, offset, true);
    central.set(name, 46); directory.push(central); offset += header.length + data.length;
  }
  const centralBytes = concat(directory), end = new Uint8Array(22), v = new DataView(end.buffer);
  v.setUint32(0, 0x06054b50, true); v.setUint16(8, entries.length, true); v.setUint16(10, entries.length, true); v.setUint32(12, centralBytes.length, true); v.setUint32(16, offset, true);
  return concat([...locals, centralBytes, end]);
}

export function exportWorkbook(template, catalog, responses) {
  const totals = consolidate(responses, catalog);
  const entries = template.map(entry => {
    let data = Uint8Array.from(atob(entry.base64), character => character.charCodeAt(0));
    if (entry.method === 8) data = new Uint8Array(inflateRawSync(data));
    else if (entry.method !== 0) throw new Error('Compression du modèle non prise en charge.');
    const sheet = catalog.sheets.find(sheet => sheet.path === entry.name);
    if (sheet) data = encoder.encode(fillWorksheet(decoder.decode(data), sheet, catalog, totals));
    return { name: entry.name, data };
  });
  return zipStored(entries);
}
