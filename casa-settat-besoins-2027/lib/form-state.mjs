export const UNSENT_FR = "Cette version de votre demande n’est pas encore enregistrée ni envoyée au coordinateur. Vos saisies sont uniquement conservées en brouillon sur cet appareil.";
export const UNSENT_AR = "لم تُسجَّل هذه النسخة من طلبكم ولم تُرسَل إلى المنسق بعد. البيانات محفوظة فقط كمسودة على هذا الجهاز.";

export function draftSnapshot(agency, values, catalogItems) {
  const name = agency.replace(/[\x00-\x1f\x7f]/g, ' ').replace(/\s+/g, ' ').trim();
  const items = [];
  for (const item of catalogItems) {
    const value = values[item.id];
    if (!value) continue;
    const raw = String(value.quantity ?? '').trim().replace(',', '.');
    const comment = String(value.comment ?? '').replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/g, '').trim();
    if (!raw && !comment) continue;
    const number = Number(raw);
    items.push({ id: item.id, quantity: raw && Number.isFinite(number) ? number : raw, comment });
  }
  return JSON.stringify({ agency: name, items });
}

export function submittedSnapshot(agency, items, catalogItems) {
  const values = Object.fromEntries(items.map(item => [item.id, { quantity: String(item.quantity), comment: item.comment }]));
  return draftSnapshot(agency, values, catalogItems);
}
