export class InputError extends Error {}

export function agencyKey(value) {
  return value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLocaleUpperCase('fr').replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

export function validateSubmission(body, catalogItems) {
  if (!body || typeof body !== 'object' || typeof body.agency !== 'string') throw new InputError('Indiquez le nom de votre agence.');
  const agency = body.agency.replace(/[\x00-\x1f\x7f]/g, ' ').replace(/\s+/g, ' ').trim();
  const key = agencyKey(agency);
  if (agency.length < 2 || agency.length > 100 || key.length < 2) throw new InputError('Le nom de l’agence doit comporter entre 2 et 100 caractères.');
  if (!Array.isArray(body.items) || !body.items.length || body.items.length > catalogItems.length) throw new InputError('Renseignez au moins une quantité.');
  const allowed = new Set(catalogItems.map(item => item.id));
  const seen = new Set();
  const items = body.items.map(item => {
    if (!item || typeof item.id !== 'string' || !allowed.has(item.id) || seen.has(item.id)) throw new InputError('Un article est invalide ou figure plusieurs fois.');
    seen.add(item.id);
    if (typeof item.quantity !== 'number' || !Number.isFinite(item.quantity) || item.quantity <= 0 || item.quantity > 100000 || Math.abs(item.quantity * 100 - Math.round(item.quantity * 100)) > 0.00001) throw new InputError('Les quantités doivent être positives, avec deux décimales au maximum (maximum 100 000).');
    if (item.comment != null && typeof item.comment !== 'string') throw new InputError('Le commentaire est invalide.');
    const comment = (item.comment || '').replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, '').trim();
    if (comment.length > 1500) throw new InputError('Chaque commentaire est limité à 1 500 caractères.');
    return { id: item.id, quantity: item.quantity, comment };
  });
  return { agency, agencyKey: key, items };
}
