import { env } from 'cloudflare:workers';
import template from './comptage-template.json';
import { InputError, agencyKey } from './validation.mjs';
import { validMonth, validateCountSubmission } from './comptage.mjs';
import { exportCountWorkbook } from './comptage-excel.mjs';
import { cookieHeader, digest, readToken, signToken, trustedWebOrigin } from './security';
import type { CountSubmission } from '../app/comptage/types';

type StoredCount = { id: string; agency: string; month: string; payload: string; created_at: string; updated_at: string };
const json = (body: unknown, status = 200, headers: Record<string,string> = {}) => Response.json(body, {status, headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...headers}});
const database = () => { if (!env.DB) throw new Error('Le service d’enregistrement est indisponible.'); return env.DB; };
const unpack = (row: StoredCount): CountSubmission => ({id:row.id,agency:row.agency,month:row.month,rows:JSON.parse(row.payload),createdAt:row.created_at,updatedAt:row.updated_at});
function requiredMonth(url: URL) { const month = url.searchParams.get('month'); if (!validMonth(month)) throw new InputError('Choisissez un mois valide.'); return month!; }

// Retry reads only: a storage restart must never duplicate a write.
async function readWithRetry<T>(operation: () => Promise<T>) {
  for (let attempt = 0; ; attempt++) {
    try { return await operation(); }
    catch (error) {
      if (attempt >= 2 || !(error instanceof Error) || !/D1_ERROR.*(?:internal error|SQLITE_NOMEM|reset|Network connection lost|overloaded)/i.test(error.message)) throw error;
      await new Promise(resolve => setTimeout(resolve, 150 * (attempt + 1)));
    }
  }
}

export async function handleComptage(request: Request, path: string): Promise<Response | null> {
  if (!path.startsWith('/api/comptage/') && !path.startsWith('/api/admin/comptage/')) return null;
  const url = new URL(request.url);
  if (request.method === 'GET' && path === '/api/comptage/session') {
    const month = requiredMonth(url);
    let session = await readToken(request,'budget_participant','participant');
    if (!session) session = crypto.randomUUID();
    const token = await signToken('participant',session,31536000);
    const agency = url.searchParams.get('agency');
    const digestValue = await digest(session);
    const owned = await readWithRetry(() => agency
      ? database().prepare('SELECT id, agency, month, payload, created_at, updated_at FROM count_submissions WHERE session_hash = ? AND month = ? AND agency_key = ? LIMIT 1').bind(digestValue,month,agencyKey(agency)).first<StoredCount>()
      : database().prepare('SELECT id, agency, month, payload, created_at, updated_at FROM count_submissions WHERE session_hash = ? AND month = ? ORDER BY updated_at DESC LIMIT 1').bind(digestValue,month).first<StoredCount>());
    return json({ready:true,submission:owned ? unpack(owned) : null,participantToken:trustedWebOrigin(request) ? token : undefined},200,{'Set-Cookie':cookieHeader(request,'budget_participant',token,31536000)});
  }
  if (request.method === 'POST' && path === '/api/comptage/submit') {
    const session = await readToken(request,'budget_participant','participant');
    if (!session) return json({error:'Votre session a expiré. Actualisez la page puis réessayez.'},401);
    const text = await request.text();
    if (text.length > 100000) return json({error:'Le comptage est trop volumineux.'},413);
    const data = validateCountSubmission(JSON.parse(text)), now = new Date().toISOString();
    const result = await database().prepare('INSERT INTO count_submissions (id, agency, agency_key, month, session_hash, payload, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(agency_key, month) DO UPDATE SET agency = excluded.agency, payload = excluded.payload, updated_at = excluded.updated_at WHERE count_submissions.session_hash = excluded.session_hash RETURNING id')
      .bind(crypto.randomUUID(),data.agency,data.agencyKey,data.month,await digest(session),JSON.stringify(data.rows),now,now).first<{id:string}>();
    if (!result) return json({error:'Cette agence a déjà transmis ce mois depuis un autre navigateur. Contactez le coordinateur pour éviter un doublon.'},409);
    return json({id:result.id,agency:data.agency,month:data.month,updatedAt:now});
  }
  if (path.startsWith('/api/admin/comptage/')) {
    if (!(await readToken(request,'budget_admin','admin'))) return json({error:'Accès réservé au coordinateur.'},401);
    if (request.method === 'GET' && path === '/api/admin/comptage/responses') {
      const month = requiredMonth(url);
      const rows = await readWithRetry(() => database().prepare('SELECT id, agency, month, payload, created_at, updated_at FROM count_submissions WHERE month = ? ORDER BY agency COLLATE NOCASE').bind(month).all<StoredCount>());
      const months = await readWithRetry(() => database().prepare('SELECT DISTINCT month FROM count_submissions ORDER BY month DESC').all<{month:string}>());
      return json({responses:rows.results.map(unpack),months:months.results.map(row=>row.month)});
    }
    if (request.method === 'GET' && path === '/api/admin/comptage/export') {
      const month = requiredMonth(url), id = url.searchParams.get('agency');
      const rows = await readWithRetry(() => id
        ? database().prepare('SELECT id, agency, month, payload, created_at, updated_at FROM count_submissions WHERE month = ? AND id = ?').bind(month,id).all<StoredCount>()
        : database().prepare('SELECT id, agency, month, payload, created_at, updated_at FROM count_submissions WHERE month = ? ORDER BY agency COLLATE NOCASE').bind(month).all<StoredCount>());
      if (!rows.results.length) return json({error:'Aucun comptage à exporter pour ce mois.'},404);
      return new Response(exportCountWorkbook(template,rows.results.map(unpack)),{headers:{'Content-Type':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','Content-Disposition':`attachment; filename="Comptage_Envois_${month}_${id ? 'agence' : 'agences'}.xlsx"`,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
    }
    if (request.method === 'POST' && path === '/api/admin/comptage/delete') {
      const text = await request.text();
      if (text.length > 1000) throw new InputError('La demande de suppression est invalide.');
      const body = JSON.parse(text);
      if (!body || typeof body.id !== 'string' || body.id.length > 80 || typeof body.updatedAt !== 'string' || body.updatedAt.length > 40) throw new InputError('La demande de suppression est invalide.');
      const removed = await database().prepare('DELETE FROM count_submissions WHERE id = ? AND updated_at = ? RETURNING id').bind(body.id,body.updatedAt).first<{id:string}>();
      return removed ? json({ok:true,id:removed.id}) : json({error:'Ce comptage a été modifié ou supprimé. Actualisez la liste.'},409);
    }
  }
  return json({error:'Ressource introuvable.'},404);
}
