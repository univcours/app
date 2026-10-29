import { InputError } from "./validation.mjs";

export function validateTrafficSubmission(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) throw new InputError("Saisie invalide.");
  const agency = typeof data.agency === "string" ? data.agency.trim().replace(/\s+/g, " ") : "";
  if (agency.length < 3 || agency.length > 120) throw new InputError("Saisissez le nom complet de votre agence (3 à 120 caractères).");
  if (/[<>{}\u0000-\u001f]/.test(agency)) throw new InputError("Le nom de l'agence comporte des caractères interdits.");
  const month = typeof data.month === "string" ? data.month : "";
  if (!/^(202[5-9]|203[0-5])-(0[1-9]|1[0-2])$/.test(month)) throw new InputError("Sélectionnez un mois valide.");
  if (!Array.isArray(data.rows) || data.rows.length < 1 || data.rows.length > 31) throw new InputError("Le relevé doit contenir les dates du mois.");
  const seen = new Set();
  let completed = 0;
  const rows = data.rows.map(entry => {
    if (!entry || typeof entry !== "object" || typeof entry.date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(entry.date) || !entry.date.startsWith(month + "-")) throw new InputError("Une date ne correspond pas au mois sélectionné.");
    const parsed = new Date(entry.date + "T00:00:00Z");
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== entry.date || seen.has(entry.date)) throw new InputError("Une date est incorrecte ou répétée.");
    seen.add(entry.date);
    const frequency = typeof entry.frequency === "string" ? entry.frequency.trim() : "";
    if (frequency && !["1/5","2/5","3/5","4/5","5/5"].includes(frequency)) throw new InputError("La fréquence doit être comprise entre 1/5 et 5/5.");
    if (!Array.isArray(entry.counts) || entry.counts.length !== 14) throw new InputError("Les 14 colonnes du canevas doivent être conservées.");
    const counts = entry.counts.map(value => {
      if (value === null || value === "") return null;
      if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > 1_000_000) throw new InputError("Les quantités doivent être des entiers positifs (0 à 1 000 000).");
      return value;
    });
    if (frequency || counts.some(value => value !== null)) completed++;
    return { date: entry.date, frequency, counts };
  }).sort((a,b) => a.date.localeCompare(b.date));
  if (!completed) throw new InputError("Renseignez au moins une date avant de transmettre le relevé.");
  const agencyKey = agency.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("fr").replace(/\s+/g, " ");
  return { agency, agencyKey, month, rows, completed };
}

export function trafficReportRow(row) {
  const payload = JSON.parse(row.payload);
  return { id: row.id, agency: row.agency, month: row.month, rows: payload.rows, createdAt: row.created_at, updatedAt: row.updated_at };
}
