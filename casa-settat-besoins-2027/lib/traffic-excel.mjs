import { zipStored } from "./excel.mjs";

const encoder = new TextEncoder();
const xml = value => String(value ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&apos;");
export const trafficColumns = [
  "Distribution des lettres ordinaires (par la tournée)",
  "Distribution des paquets ordinaires",
  "Distribution aux autorités locales",
  "Distribution des lettres recommandées",
  "Distribution des paquets recommandés",
  "Distribution E-BARKI@",
  "Distribution LRH",
  "Distribution AMANA",
  "Envois recommandés avisés au guichet",
  "Envois E-BARKI@ avisés au guichet",
  "Envois LRH avisés au guichet",
  "Envois AMANA avisés au guichet",
  "Tri dans les boîtes postales de l'agence",
  "Tri des avis du courrier enregistré dans les boîtes postales",
];
const colLetter = n => String.fromCharCode(65 + n);
const str = (ref, value, style = 0) => '<c r="' + ref + '" s="' + style + '" t="inlineStr"><is><t xml:space="preserve">' + xml(value) + '</t></is></c>';
const num = (ref, value, style = 5) => '<c r="' + ref + '" s="' + style + '"><v>' + Number(value || 0) + '</v></c>';
const line = (n, cells, height = 23) => '<row r="' + n + '" ht="' + height + '" customHeight="1">' + cells.join("") + '</row>';
const dateFrench = iso => iso.slice(8,10) + "/" + iso.slice(5,7) + "/" + iso.slice(0,4);
function totals(report) {
  const t = Array(14).fill(0);
  for (const day of report.rows) for (let i = 0; i < 14; i++) t[i] += Number(day.counts[i] || 0);
  return t;
}
function sheetXml(report) {
  const [yyyy, mm] = report.month.split("-");
  const frenchMonth = new Intl.DateTimeFormat("fr-FR", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(Date.UTC(Number(yyyy), Number(mm) - 1, 1)));
  const lines = [];
  lines.push(line(1, [str("A1", "Agence ABB : " + report.agency, 1)], 27));
  lines.push(line(2, [str("A2", "Comptage des envois — " + frenchMonth, 1)], 33));
  lines.push(line(3, [
    str("A3", "Dates", 2), str("B3", "Fréquence de distribution (1/5, 2/5, 3/5, 4/5, 5/5)", 2),
    str("C3", "Trafic distribué du courrier ordinaire", 2),
    str("F3", "Trafic distribué du courrier enregistré", 2),
    str("K3", "Les avisés au guichet de l'agence", 2),
    str("O3", "Trafic distribué en boîtes postales", 2),
  ], 44));
  lines.push(line(4, trafficColumns.map((name, i) => str(colLetter(i + 2) + "4", name, 3)), 105));
  const days = [...report.rows].sort((a, b) => a.date.localeCompare(b.date));
  days.forEach((day, index) => {
    const r = index + 5;
    const cells = [str("A" + r, dateFrench(day.date), 4)];
    if (day.frequency) cells.push(str("B" + r, day.frequency, 4));
    for (let i = 0; i < 14; i++) if (day.counts[i] !== null && day.counts[i] !== undefined) cells.push(num(colLetter(i + 2) + r, day.counts[i]));
    lines.push(line(r, cells));
  });
  const totalRow = 5 + days.length, t = totals(report);
  lines.push(line(totalRow, [
    str("A" + totalRow, "TOTAL", 6),
    ...t.map((value, i) => '<c r="' + colLetter(i + 2) + totalRow + '" s="7"><f>SUM(' + colLetter(i + 2) + '5:' + colLetter(i + 2) + (totalRow - 1) + ')</f><v>' + value + '</v></c>'),
  ], 29));
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<sheetViews><sheetView workbookViewId="0"><pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>' +
    '<sheetFormatPr defaultRowHeight="20"/><cols><col min="1" max="1" width="14" customWidth="1"/><col min="2" max="2" width="18" customWidth="1"/><col min="3" max="16" width="19" customWidth="1"/></cols>' +
    '<sheetData>' + lines.join("") + '</sheetData>' +
    '<mergeCells count="8"><mergeCell ref="A1:P1"/><mergeCell ref="A2:P2"/><mergeCell ref="A3:A4"/><mergeCell ref="B3:B4"/><mergeCell ref="C3:E3"/><mergeCell ref="F3:J3"/><mergeCell ref="K3:N3"/><mergeCell ref="O3:P3"/></mergeCells>' +
    '<pageMargins left="0.2" right="0.2" top="0.4" bottom="0.4" header="0.2" footer="0.2"/><pageSetup orientation="landscape" paperSize="9" fitToWidth="1"/>' +
    '</worksheet>';
}
function summaryXml(reports) {
  const labels = ["Agence", "Mois", "Jours renseignés", ...trafficColumns];
  const rows = [line(1, [str("A1", "RÉCAPITULATIF — COMPTAGE DES ENVOIS", 1)], 32),
    line(2, labels.map((v,i) => str(colLetter(i) + "2", v, 3)), 96)];
  reports.forEach((report, index) => {
    const r = index + 3, vals = totals(report);
    rows.push(line(r, [str("A" + r, report.agency, 4), str("B" + r, report.month, 4),
      num("C" + r, report.rows.filter(x => x.frequency || x.counts.some(v => v !== null)).length),
      ...vals.map((value, i) => num(colLetter(i + 3) + r, value))]));
  });
  return '<?xml version="1.0" encoding="UTF-8"?>' +
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
    '<sheetViews><sheetView workbookViewId="0"><pane ySplit="2" topLeftCell="A3" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>' +
    '<cols><col min="1" max="1" width="30" customWidth="1"/><col min="2" max="2" width="15" customWidth="1"/><col min="3" max="17" width="18" customWidth="1"/></cols><sheetData>' + rows.join("") + '</sheetData><mergeCells count="1"><mergeCell ref="A1:Q1"/></mergeCells>' +
    '<pageMargins left="0.2" right="0.2" top="0.4" bottom="0.4" header="0.2" footer="0.2"/><pageSetup orientation="landscape"/></worksheet>';
}
const styles = '<?xml version="1.0" encoding="UTF-8"?>' +
  '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
  '<fonts count="2"><font><sz val="10"/><name val="Aptos"/></font><font><b/><sz val="10"/><name val="Aptos"/><color rgb="FF23423E"/></font></fonts>' +
  '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFDCE9E5"/><bgColor indexed="64"/></patternFill></fill></fills>' +
  '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"><color rgb="FF9AABA7"/></left><right style="thin"><color rgb="FF9AABA7"/></right><top style="thin"><color rgb="FF9AABA7"/></top><bottom style="thin"><color rgb="FF9AABA7"/></bottom><diagonal/></border></borders>' +
  '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
  '<cellXfs count="8">' +
  '<xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>' +
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" applyAlignment="1"><alignment vertical="center"/></xf>' +
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>' +
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>' +
  '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" applyAlignment="1"><alignment horizontal="center"/></xf>' +
  '<xf numFmtId="1" fontId="0" fillId="0" borderId="1" applyAlignment="1"><alignment horizontal="center"/></xf>' +
  '<xf numFmtId="0" fontId="1" fillId="2" borderId="1"/>' +
  '<xf numFmtId="1" fontId="1" fillId="2" borderId="1"/>' +
  '</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';
export function exportTrafficWorkbook(reports) {
  if (!Array.isArray(reports) || !reports.length) throw new Error("Aucun comptage à exporter.");
  if (reports.length > 150) throw new Error("Sélectionnez un mois : trop de feuilles pour un export unique.");
  const worksheets = [summaryXml(reports), ...reports.map(sheetXml)];
  const sheetNames = ["Récapitulatif"], used = new Set(["Récapitulatif"]);
  reports.forEach((r, i) => {
    let base = (r.agency.replace(/[\[\]*/:?\\]/g, " ").trim() + " " + r.month).slice(0, 27) || "Agence";
    let name = base;
    while (used.has(name)) name = base.slice(0, 25) + "-" + i;
    used.add(name); sheetNames.push(name);
  });
  const sheetElems = sheetNames.map((name, i) => '<sheet name="' + xml(name) + '" sheetId="' + (i+1) + '" r:id="rId' + (i+1) + '"/>').join("");
  const workbook = '<?xml version="1.0" encoding="UTF-8"?>' +
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' + sheetElems + '</sheets><calcPr fullCalcOnLoad="1"/></workbook>';
  const rels = '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    worksheets.map((_s, i) => '<Relationship Id="rId' + (i+1) + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' + (i+1) + '.xml"/>').join("") +
    '<Relationship Id="rId' + (worksheets.length+1) + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';
  const types = '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
    worksheets.map((_s,i) => '<Override PartName="/xl/worksheets/sheet' + (i+1) + '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join("") + '</Types>';
  const entries = [
    { name: "[Content_Types].xml", data: encoder.encode(types) },
    { name: "_rels/.rels", data: encoder.encode('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>') },
    { name: "xl/workbook.xml", data: encoder.encode(workbook) },
    { name: "xl/_rels/workbook.xml.rels", data: encoder.encode(rels) },
    { name: "xl/styles.xml", data: encoder.encode(styles) },
    ...worksheets.map((data, i) => ({ name: "xl/worksheets/sheet" + (i+1) + ".xml", data: encoder.encode(data) })),
  ];
  return zipStored(entries);
}