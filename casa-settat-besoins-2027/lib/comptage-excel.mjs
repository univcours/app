import { inflateRawSync } from 'node:zlib';
import { zipStored } from './excel.mjs';
import { COUNT_FIELDS, countTotals, dateLabel, monthLabel, templateDates } from './comptage.mjs';

const encoder = new TextEncoder(), decoder = new TextDecoder();
const escape = value => String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');
const textCell = (ref, value, style = '') => `<x:c r="${ref}"${style ? ` s="${style}"` : ''} t="inlineStr"><x:is><x:t xml:space="preserve">${escape(value)}</x:t></x:is></x:c>`;
export function countAgencyAndRoute(name) {
  const match = /^(.*?) — tournée de distribution (10|[1-9])$/.exec(name);
  return match ? { agency: match[1], tournee: Number(match[2]) } : { agency: name, tournee: null };
}
const numberCell = (ref, value, style = '22', formula = '') => `<x:c r="${ref}" s="${style}">${formula ? `<x:f>${formula}</x:f>` : ''}<x:v>${value}</x:v></x:c>`;

export function fillCountWorksheet(original, submission) {
  const styleAt = (ref, fallback = '') => /\bs="(\d+)"/.exec(new RegExp('<x:c\\b[^>]*\\br="' + ref + '"[^>]*>').exec(original)?.[0] || '')?.[1] || fallback;
  const styles = { title:styleAt('A1'), date:styleAt('A5'), frequency:styleAt('B5'), body:styleAt('C5'), total:styleAt('C24'), totalLabel:styleAt('A24') };
  const dates = [...new Set([...templateDates(submission.month), ...submission.rows.map(row => row.date)])].sort();
  const values = new Map(submission.rows.map(row => [row.date, row]));
  const month = monthLabel(submission.month);
  const identity = countAgencyAndRoute(submission.agency);
  const title = `Comptage des envois de la période allant du ${dateLabel(dates[0])} au ${dateLabel(dates.at(-1))} (${month})`;
  const header = original.match(/<x:sheetData>([\s\S]*?)<x:row r="5"/)[1]
    .replace(/<x:c r="A1"[\s\S]*?<\/x:c>/, textCell('A1', `${identity.agency}${identity.tournee === null ? '' : ` T${identity.tournee}`}`, styles.title))
    .replace(/<x:c r="A2"[^>]*(?:\/>|>[\s\S]*?<\/x:c>)/, textCell('A2', `Tournée N°: ${identity.tournee ?? '—'}`, styleAt('A2')))
    .replace(/<x:c r="E1"[\s\S]*?<\/x:c>/, textCell('E1', title, styles.title));
  const rows = dates.map((date, index) => {
    const rowNumber = index + 5, row = values.get(date);
    const cells = [`<x:c r="A${rowNumber}" s="${styles.date}" t="d"><x:v>${date}T00:00:00.000Z</x:v></x:c>`];
    cells.push(row?.frequency ? textCell('B' + rowNumber, `${row.frequency}/5`, styles.frequency) : `<x:c r="B${rowNumber}" s="${styles.frequency}"/>`);
    for (let column = 0; column < COUNT_FIELDS.length; column++) {
      const ref = String.fromCharCode(67 + column) + rowNumber;
      cells.push(row?.values[column] !== null && row?.values[column] !== undefined ? numberCell(ref, row.values[column], styles.body) : `<x:c r="${ref}" s="${styles.body}"/>`);
    }
    return `<x:row r="${rowNumber}" ht="24" customHeight="1">${cells.join('')}</x:row>`;
  });
  const lastRow = dates.length + 4, totalRow = lastRow + 1;
  const totalCells = countTotals(submission.rows).map((total, index) => {
    const column = String.fromCharCode(67 + index);
    return numberCell(column + totalRow, total, styles.total, `SUM(${column}5:${column}${lastRow})`);
  }).join('');
  rows.push(`<x:row r="${totalRow}" ht="25" customHeight="1">${textCell('A' + totalRow, 'TOTAL', styles.totalLabel)}<x:c r="B${totalRow}" s="${styles.totalLabel}"/>${totalCells}</x:row>`);
  return original.replace(/<x:sheetData>[\s\S]*?<\/x:sheetData>/, `<x:sheetData>${header}${rows.join('')}</x:sheetData>`)
    .replace('</x:worksheet>', '<x:pageSetup paperSize="8" orientation="landscape" fitToWidth="1" fitToHeight="1"/></x:worksheet>');
}

export function exportCountWorkbook(template, submissions) {
  if (!submissions.length) throw new Error('Aucun comptage à exporter.');
  const entries = template.map(entry => {
    let data = Uint8Array.from(atob(entry.base64), char => char.charCodeAt(0));
    if (entry.method === 8) data = new Uint8Array(inflateRawSync(data));
    return { name: entry.name, data };
  });
  const source = decoder.decode(entries.find(entry => entry.name === 'xl/worksheets/sheet1.xml').data);
  const used = new Set();
  const names = submissions.map(submission => {
    const identity = countAgencyAndRoute(submission.agency);
    const suffix = identity.tournee === null ? '' : ` T${identity.tournee}`;
    const clean = identity.agency.replace(/[\x00-\x1f\x7f\[\]:*?\\/]/g, ' ').trim().replace(/^'+|'+$/g, '') || 'Agence';
    let name = clean.slice(0, 31 - suffix.length) + suffix, index = 2;
    while (used.has(name.toLocaleUpperCase('fr'))) { const extra = ` (${index++})`; name = clean.slice(0, 31 - suffix.length - extra.length) + suffix + extra; }
    used.add(name.toLocaleUpperCase('fr')); return name;
  });
  const sheets = submissions.map((submission, index) => ({ name: `xl/worksheets/sheet${index + 1}.xml`, data: encoder.encode(fillCountWorksheet(source, submission)) }));
  const workbook = `<?xml version="1.0" encoding="utf-8"?><x:workbook xmlns:x="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><x:sheets>${names.map((name, index) => `<x:sheet name="${escape(name)}" sheetId="${index + 1}" r:id="countSheet${index + 1}"/>`).join('')}</x:sheets><x:calcPr fullCalcOnLoad="1"/></x:workbook>`;
  const result = entries.filter(entry => !entry.name.startsWith('xl/worksheets/')).map(entry => {
    if (entry.name === 'xl/workbook.xml') return { ...entry, data: encoder.encode(workbook) };
    if (entry.name === 'xl/_rels/workbook.xml.rels') {
      const xml = decoder.decode(entry.data).replace(/<(?:\w+:)?Relationship\b[^>]*Type="[^"]*\/worksheet"[^>]*\/>/g, '')
        .replace(/<\/(?:\w+:)?Relationships>/, `${submissions.map((_, index) => `<Relationship Id="countSheet${index + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${index + 1}.xml"/>`).join('')}</Relationships>`);
      return { ...entry, data: encoder.encode(xml) };
    }
    if (entry.name === '[Content_Types].xml') {
      const xml = decoder.decode(entry.data).replace(/<(?:\w+:)?Override\b[^>]*PartName="\/xl\/worksheets\/[^\"]+"[^>]*\/>/g, '')
        .replace(/<\/(?:\w+:)?Types>/, `${submissions.map((_, index) => `<Override PartName="/xl/worksheets/sheet${index + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('')}</Types>`);
      return { ...entry, data: encoder.encode(xml) };
    }
    return entry;
  });
  return zipStored([...result, ...sheets]);
}
