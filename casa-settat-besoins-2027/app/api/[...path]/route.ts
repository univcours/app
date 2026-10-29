import { env } from "cloudflare:workers";
import catalog from "../../../lib/catalog.json";
import template from "../../../lib/excel-template.json";
import { InputError, validateSubmission } from "../../../lib/validation.mjs";
import { exportWorkbook } from "../../../lib/excel.mjs";
import { cookieHeader, digest, equalSecret, readToken, sameOrigin, signToken, trustedWebOrigin } from "../../../lib/security";
import { handleComptage } from "../../../lib/comptage-api";
import { handleControle } from "../../../lib/controle-api";
import { isControleSiteOpen } from "../../../lib/controle-auth";

export const dynamic = "force-dynamic";
type Item = { id: string; quantity: number; comment: string };
type Submission = { id: string; agency: string; items: Item[]; createdAt: string; updatedAt: string };
type Row = { id: string; agency: string; payload: string; created_at: string; updated_at: string };
const json = (data: unknown, status = 200, headers: Record<string, string> = {}) => Response.json(data, { status, headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", ...headers } });
const db = () => { if (!env.DB) throw new Error("Le service d’enregistrement est indisponible."); return env.DB; };
function responseRow(row: Row): Submission { return { id: row.id, agency: row.agency, items: JSON.parse(row.payload), createdAt: row.created_at, updatedAt: row.updated_at }; }
async function isAdmin(request: Request) { return !!(await readToken(request, "budget_admin", "admin")); }

async function handle(request: Request) {
  const path = new URL(request.url).pathname;
  if (request.headers.has("origin") && !sameOrigin(request) && !trustedWebOrigin(request)) return json({ error: "Origine non autorisée." }, 403);
  if (request.method === "POST" && !sameOrigin(request) && !trustedWebOrigin(request)) return json({ error: "Cette demande doit être envoyée depuis le formulaire." }, 403);
  if (request.method === "POST" && Number(request.headers.get("content-length") || 0) > (path === "/api/admin/controle/import" ? 2500000 : 400000)) return json({ error: "La demande est trop volumineuse." }, 413);
  // The coordinator must always be able to log in and reopen the service.
  // All other public APIs (including monthly comptage) are closed centrally.
  const bypassGate=path.startsWith('/api/admin/')||path==='/api/controle/site-status'||path==='/api/controle/health';
  if(!bypassGate&&!(await isControleSiteOpen()))
    return json({error:'Le site est temporairement fermé par le coordinateur.',siteClosed:true},423);
  const controleResponse = await handleControle(request, path);
  if (controleResponse) return controleResponse;
  const countResponse = await handleComptage(request, path);
  if (countResponse) return countResponse;
  if (request.method === "GET" && path === "/api/session") {
    let session = await readToken(request, "budget_participant", "participant");
    const headers: Record<string, string> = {};
    if (!session) {
      session = crypto.randomUUID();
      headers["Set-Cookie"] = cookieHeader(request, "budget_participant", await signToken("participant", session, 31536000), 31536000);
    }
    const owned = await db().prepare("SELECT id, agency, payload, created_at, updated_at FROM submissions WHERE session_hash = ? ORDER BY updated_at DESC LIMIT 1").bind(await digest(session)).first<Row>();
    const participantToken = trustedWebOrigin(request) ? await signToken("participant", session, 31536000) : undefined;
    return json({ ready: true, admin: await isAdmin(request), submission: owned ? responseRow(owned) : null, participantToken }, 200, headers);
  }
  if (request.method === "POST" && path === "/api/submit") {
    const session = await readToken(request, "budget_participant", "participant");
    if (!session) return json({ error: "Votre session a expiré. Actualisez la page puis réessayez." }, 401);
    const bodyText = await request.text();
    if (bodyText.length > 350000) return json({ error: "La demande est trop volumineuse." }, 413);
    const data = validateSubmission(JSON.parse(bodyText), catalog.items);
    const hash = await digest(session), now = new Date().toISOString();
    // Atomic ownership check and upsert: retries replace the same agency,
    // and a different browser cannot overwrite an existing agency.
    const result = await db().prepare("INSERT INTO submissions (id, agency, agency_key, session_hash, payload, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(agency_key) DO UPDATE SET agency = excluded.agency, payload = excluded.payload, updated_at = excluded.updated_at WHERE submissions.session_hash = excluded.session_hash RETURNING id")
      .bind(crypto.randomUUID(), data.agency, data.agencyKey, hash, JSON.stringify(data.items), now, now).first<{ id: string }>();
    if (!result) return json({ error: "Cette agence a déjà transmis ses besoins depuis un autre navigateur. Contactez le coordinateur pour éviter un doublon." }, 409);
    return json({ id: result.id, updatedAt: now, agency: data.agency, itemCount: data.items.length });
  }
  if (request.method === "POST" && path === "/api/admin/login") {
    if (!env.ADMIN_PASSWORD) throw new Error("L’accès coordinateur n’est pas encore configuré.");
    const ip = request.headers.get("cf-connecting-ip") || "shared";
    const window = Math.floor(Date.now() / 900000);
    const attemptKey = await digest(`login:${ip}:${window}:${env.SESSION_SECRET}`);
    const attempt = await db().prepare("INSERT INTO login_attempts (key, attempts, expires_at) VALUES (?, 1, ?) ON CONFLICT(key) DO UPDATE SET attempts = attempts + 1 RETURNING attempts")
      .bind(attemptKey, Date.now() + 900000).first<{ attempts: number }>();
    if ((attempt?.attempts || 0) > 10) return json({ error: "Trop de tentatives. Réessayez dans 15 minutes." }, 429);
    const text = await request.text();
    if (text.length > 1000) return json({ error: "Mot de passe incorrect." }, 401);
    const body = JSON.parse(text);
    if (typeof body.password !== "string" || !(await equalSecret(body.password, env.ADMIN_PASSWORD))) return json({ error: "Mot de passe incorrect." }, 401);
    await db().batch([
      db().prepare("DELETE FROM login_attempts WHERE key = ?").bind(attemptKey),
      db().prepare("DELETE FROM login_attempts WHERE expires_at < ?").bind(Date.now()),
    ]);
    const token = await signToken("admin", crypto.randomUUID(), 28800);
    return json({ ok: true, adminToken: trustedWebOrigin(request) ? token : undefined }, 200, { "Set-Cookie": cookieHeader(request, "budget_admin", token, 28800) });
  }
  if (request.method === "POST" && path === "/api/admin/logout") {
    return json({ ok: true }, 200, { "Set-Cookie": cookieHeader(request, "budget_admin", "", 0) });
  }
  if (path.startsWith("/api/admin/")) {
    if (!(await isAdmin(request))) return json({ error: "Accès réservé au coordinateur." }, 401);
    if (request.method === "POST" && path === "/api/admin/delete") {
      const text = await request.text();
      if (text.length > 1000) return json({ error: "La demande de suppression est invalide." }, 400);
      const body = JSON.parse(text);
      if (!body || typeof body.id !== "string" || body.id.length > 80 || typeof body.updatedAt !== "string" || body.updatedAt.length > 40) return json({ error: "La demande de suppression est invalide." }, 400);
      const removed = await db().prepare("DELETE FROM submissions WHERE id = ? AND updated_at = ? RETURNING id, agency").bind(body.id, body.updatedAt).first<{ id: string; agency: string }>();
      if (!removed) return json({ error: "Cette demande a été modifiée ou supprimée. Actualisez la liste avant de recommencer." }, 409);
      return json({ ok: true, id: removed.id, agency: removed.agency });
    }
    const rows = await db().prepare("SELECT id, agency, payload, created_at, updated_at FROM submissions ORDER BY agency COLLATE NOCASE").all<Row>();
    const responses = rows.results.map(responseRow);
    if (request.method === "GET" && path === "/api/admin/responses") return json({ responses });
    if (request.method === "GET" && path === "/api/admin/export") {
      const id = new URL(request.url).searchParams.get("agency");
      const selected = id ? responses.filter(response => response.id === id) : responses;
      if (!selected.length) return json({ error: "Aucune demande à exporter." }, 404);
      const bytes = exportWorkbook(template, catalog, selected);
      const date = new Intl.DateTimeFormat("fr-CA", { timeZone: "Africa/Casablanca", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
      return new Response(bytes, { headers: { "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "Content-Disposition": `attachment; filename="Besoins_2027_${id ? 'agence' : 'consolides'}_${date}.xlsx"`, "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" } });
    }
  }
  return json({ error: "Ressource introuvable." }, 404);
}

async function endpoint(request: Request) {
  const cors = trustedWebOrigin(request);
  function withCors(response: Response) {
    if (cors) {
      response.headers.set("Access-Control-Allow-Origin", request.headers.get("origin")!);
      response.headers.set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
      response.headers.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
      response.headers.set("Access-Control-Expose-Headers", "Content-Disposition");
      response.headers.set("Vary", "Origin");
    }
    return response;
  }
  if (request.method === "OPTIONS") return cors ? withCors(new Response(null, { status: 204 })) : json({ error: "Origine non autorisée." }, 403);
  try { return withCors(await handle(request)); }
  catch (error) {
    if (error instanceof InputError || error instanceof SyntaxError) return withCors(json({ error: error instanceof SyntaxError ? "La demande est invalide." : error.message }, 400));
    console.error("Budget request failed", error instanceof Error ? error.message : "Unknown error");
    return withCors(json({ error: error instanceof Error && error.message.includes("limite Excel") ? error.message : "Le service est momentanément indisponible. Vos saisies sont conservées dans ce navigateur. Réessayez dans un instant." }, 503));
  }
}
export const GET = endpoint;
export const POST = endpoint;
export const DELETE = endpoint;
export const OPTIONS = endpoint;
