import { InputError, agencyKey } from './validation.mjs';

export const DEFAULT_COUNT_MONTH = '2026-11';
export const COUNT_GROUPS = [
  { label: 'Trafic distribué du courrier ordinaire (Nombre de courriers sortants distribués par tournée au cours de la journée)', count: 3 },
  { label: 'Trafic distribué du courrier enregistré (Nombre de courriers sortants distribués par tournée au cours de la journée)', count: 5 },
  { label: 'Les avisés au guichet de l’agence', count: 4 },
  { label: 'Trafic distribué en boîtes postales', count: 2 },
];
export const COUNT_FIELDS = [
  'Distribution des lettres ordinaires (par la tournée)',
  'Distribution des paquets ordinaires',
  'Distribution aux autorités locales',
  'Distribution des lettres recommandées',
  'Distribution des paquets recommandés',
  'Distribution E-BARKI@',
  'Distribution LRH',
  'Distribution AMANA',
  'Nombre d’envois recommandés avisés au guichet',
  'Nombre d’envois E-BARKI@ avisés au guichet',
  'Nombre d’envois LRH avisés au guichet',
  'Nombre d’envois AMANA avisés au guichet',
  'Tri dans les boîtes postales de l’agence',
  'Tri des avis du courrier enregistré (E-BARKI@, LRH…) dans les boîtes postales de l’agence',
];
export function validMonth(month) { return typeof month === 'string' && /^20\d\d-(0[1-9]|1[0-2])$/.test(month); }
export function monthLabel(month) {
  return validMonth(month) ? new Intl.DateTimeFormat('fr-FR', { month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(month + '-01T12:00:00Z')) : '';
}
export function dateLabel(date) { return date.slice(8, 10) + '/' + date.slice(5, 7) + '/' + date.slice(0, 4); }
export function monthDates(month) {
  if (!validMonth(month)) return [];
  const [year, number] = month.split('-').map(Number);
  return Array.from({ length: new Date(Date.UTC(year, number, 0)).getUTCDate() }, (_, day) => `${month}-${String(day + 1).padStart(2, '0')}`);
}
export function templateDates(month) {
  return monthDates(month).filter(date => {
    const weekday = new Date(date + 'T12:00:00Z').getUTCDay();
    // The supplied November sheet explicitly omits these two dates.
    return weekday !== 0 && weekday !== 6 && !['2026-11-06', '2026-11-18'].includes(date);
  });
}
export function cleanCountAgency(value) {
  if (typeof value !== 'string') throw new InputError('Indiquez le nom de votre agence.');
  const agency = value.replace(/[\x00-\x1f\x7f\ufffe\uffff]/g, ' ').replace(/\s+/g, ' ').trim();
  if (agency.length < 2 || agency.length > 100 || agencyKey(agency).length < 2) throw new InputError('Le nom de l’agence doit comporter entre 2 et 100 caractères.');
  return agency;
}
export function validateCountSubmission(body) {
  if (!body || typeof body !== 'object') throw new InputError('Le comptage est invalide.');
  const agency = cleanCountAgency(body.agency);
  if (!validMonth(body.month)) throw new InputError('Choisissez un mois valide.');
  const allowed = new Set(monthDates(body.month)), seen = new Set();
  if (!Array.isArray(body.rows) || !body.rows.length || body.rows.length > 31) throw new InputError('Renseignez au moins une journée.');
  let hasCount = false;
  const rows = body.rows.map(row => {
    if (!row || typeof row.date !== 'string' || !allowed.has(row.date) || seen.has(row.date)) throw new InputError('Une date est invalide ou figure plusieurs fois.');
    seen.add(row.date);
    if (!Array.isArray(row.values) || row.values.length !== COUNT_FIELDS.length) throw new InputError('Chaque journée doit respecter les 14 colonnes du canevas.');
    const values = row.values.map(value => {
      if (value === null) return null;
      if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0 || value > 10000000) throw new InputError(`Vérifiez le ${dateLabel(row.date)} : les nombres d’envois doivent être des entiers de 0 à 10 000 000.`);
      hasCount = true; return value;
    });
    if (row.frequency !== null && (!Number.isInteger(row.frequency) || row.frequency < 1 || row.frequency > 5)) throw new InputError('La fréquence de distribution doit être comprise entre 1/5 et 5/5.');
    if (values.some(value => value !== null) && row.frequency === null) throw new InputError(`Choisissez la fréquence de distribution du ${dateLabel(row.date)}.`);
    return { date: row.date, frequency: row.frequency, values };
  }).filter(row => row.frequency !== null || row.values.some(value => value !== null)).sort((a, b) => a.date.localeCompare(b.date));
  if (!hasCount) throw new InputError('Renseignez au moins un nombre d’envois. Saisissez 0 lorsque le nombre est nul.');
  return { agency, agencyKey: agencyKey(agency), month: body.month, rows };
}
export function countTotals(rows) {
  return COUNT_FIELDS.map((_, index) => rows.reduce((sum, row) => sum + (row.values[index] ?? 0), 0));
}
export function countDraftRows(draft) {
  return Object.entries(draft).filter(([, row]) => row.frequency !== '' || row.values.some(value => value !== '')).map(([date, row]) => ({
    date, frequency: row.frequency === '' ? null : Number(row.frequency),
    values: row.values.map(value => value === '' ? null : (/^\d+$/.test(value) ? Number(value) : NaN)),
  }));
}
export function countFingerprint(agency, month, draft) {
  const rows = Object.entries(draft).filter(([, row]) => row.frequency !== '' || row.values.some(value => value !== '')).sort(([a], [b]) => a.localeCompare(b)).map(([date, row]) => [date, row.frequency, row.values.map(value => /^\d+$/.test(value) ? Number(value) : value)]);
  return JSON.stringify([agency.trim().replace(/\s+/g, ' '), month, rows]);
}
export function countRowsToDraft(rows) { return Object.fromEntries(rows.map(row => [row.date, { frequency: row.frequency === null ? '' : String(row.frequency), values: row.values.map(value => value === null ? '' : String(value)) }])); }
