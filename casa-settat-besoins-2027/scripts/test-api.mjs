import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import vm from 'node:vm';
import { DatabaseSync } from 'node:sqlite';
import { webcrypto } from 'node:crypto';
import { inflateRawSync } from 'node:zlib';
import ts from 'typescript';

// Exercise the actual route handlers against an isolated SQLite database and
// test-only secrets. No HTTP server or production data is involved.
const root = path.resolve(import.meta.dirname, '..');
const sqlite = new DatabaseSync(':memory:');
sqlite.exec(await fs.readFile(path.join(root, 'drizzle/0000_slim_the_leader.sql'), 'utf8'));
function prepared(sql, bindings = []) {
  return {
    bind(...args) { return prepared(sql, args); },
    async first() { return sqlite.prepare(sql).get(...bindings) || null; },
    async all() { return { results: sqlite.prepare(sql).all(...bindings), success: true }; },
  };
}
const environment = { DB: { prepare: sql => prepared(sql), async batch(statements) { sqlite.exec('BEGIN'); try { const result = []; for (const statement of statements) result.push(await statement.all()); sqlite.exec('COMMIT'); return result; } catch (error) { sqlite.exec('ROLLBACK'); throw error; } } }, SESSION_SECRET: 'test-only-session-secret-with-more-than-32-characters', ADMIN_PASSWORD: 'test-only-not-a-production-password', PUBLIC_WEB_ORIGIN: 'https://univcours.github.io' };
const context = vm.createContext({ Request, Response, URL, TextEncoder, TextDecoder, Uint8Array, DataView, crypto: webcrypto, btoa, atob, console });
const cache = new Map();
const synthetic = (identifier, exports) => new vm.SyntheticModule(Object.keys(exports), function() { for (const [key, value] of Object.entries(exports)) this.setExport(key, value); }, { context, identifier });
async function load(identifier) {
  if (cache.has(identifier)) return cache.get(identifier);
  let module;
  if (identifier === 'cloudflare:workers') module = synthetic(identifier, { env: environment });
  else if (identifier === 'node:zlib') module = synthetic(identifier, { inflateRawSync });
  else if (identifier.endsWith('.json')) module = synthetic(identifier, { default: JSON.parse(await fs.readFile(identifier, 'utf8')) });
  else {
    const source = await fs.readFile(identifier, 'utf8');
    const code = identifier.endsWith('.ts') ? ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText : source;
    module = new vm.SourceTextModule(code, { context, identifier });
  }
  cache.set(identifier, module); return module;
}
const module = await load(path.join(root, 'app/api/[...path]/route.ts'));
await module.link(async (specifier, reference) => {
  let identifier = specifier.startsWith('.') ? path.resolve(path.dirname(reference.identifier), specifier) : specifier;
  if (specifier.startsWith('.') && !path.extname(identifier)) identifier += '.ts';
  return load(identifier);
});
await module.evaluate();
const endpoint = module.namespace;
async function request(url, { method = 'GET', cookie = '', body, origin = 'https://budget.test', ip = 'test', authorization = '' } = {}) {
  const headers = { cookie, 'cf-connecting-ip': ip };
  if (origin) headers.origin = origin;
  if (authorization) headers.authorization = authorization;
  if (method === 'POST') headers['content-type'] = 'application/json';
  const req = new Request('https://budget.test' + url, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return endpoint[method](req);
}
const cookieFrom = response => response.headers.get('set-cookie').split(';')[0];
const item = (quantity, comment = '') => ({ id: 's1-r10', quantity, comment });
assert.equal((await request('/api/admin/responses')).status, 401);
assert.equal((await request('/api/admin/export')).status, 401);
assert.equal((await request('/api/submit', { method: 'POST', body: { agency: 'Agence A', items: [item(1)] } })).status, 401);

const sessionA = await request('/api/session'), cookieA = cookieFrom(sessionA);
assert.match(sessionA.headers.get('set-cookie'), /HttpOnly/);
assert.match(sessionA.headers.get('set-cookie'), /SameSite=Strict/);
assert.match(sessionA.headers.get('set-cookie'), /Secure/);
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieA, origin: 'https://other.test', body: { agency: 'Agence Settat', items: [item(3)] } })).status, 403);
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieA, body: { agency: 'Agence Settat', items: [item(-1)] } })).status, 400);
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieA, body: { agency: 'Agence Settat', items: [item(3, 'Remplacement <HS>')] } })).status, 200);
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieA, body: { agency: 'Agence Settat', items: [item(4, 'Demande mise à jour')] } })).status, 200);
assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM submissions').get().n, 1, 'An update must not duplicate an agency');
const own = await (await request('/api/session', { cookie: cookieA })).json();
assert.equal(own.submission.items[0].quantity, 4);
const cookieB = cookieFrom(await request('/api/session'));
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieB, body: { agency: 'AGENCE SÉTTAT', items: [item(99)] } })).status, 409);
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieB, body: { agency: 'Agence Casablanca', items: [item(2, 'Nouveau besoin')] } })).status, 200);
const other = await (await request('/api/session', { cookie: cookieB })).json();
assert.equal(other.submission.agency, 'Agence Casablanca');
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieA.slice(0, -1) + 'X', body: { agency: 'Agence Intruse', items: [item(1)] } })).status, 401);
assert.equal((await request('/api/admin/login', { method: 'POST', body: { password: 'wrong' } })).status, 401);
const login = await request('/api/admin/login', { method: 'POST', body: { password: environment.ADMIN_PASSWORD } });
assert.equal(login.status, 200);
const adminCookie = cookieFrom(login);
const list = await (await request('/api/admin/responses', { cookie: adminCookie })).json();
assert.equal(list.responses.length, 2);
const file = await request('/api/admin/export', { cookie: adminCookie });
assert.equal(file.status, 200);
assert.equal(file.headers.get('content-type'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
const bytes = new Uint8Array(await file.arrayBuffer());
assert.equal(new DataView(bytes.buffer).getUint32(0, true), 0x04034b50);
const text = new TextDecoder().decode(bytes);
assert.match(text, /r="H10"[^>]*><v>6<\/v>/);
assert.match(text, /Agence Settat : 4 — Demande mise à jour/);
assert.match(text, /Agence Casablanca : 2 — Nouveau besoin/);
const single = await request('/api/admin/export?agency=' + encodeURIComponent(list.responses.find(row => row.agency === 'Agence Settat').id), { cookie: adminCookie });
assert.match(new TextDecoder().decode(await single.arrayBuffer()), /r="H10"[^>]*><v>4<\/v>/);
assert.equal((await request('/api/admin/export?agency=missing', { cookie: adminCookie })).status, 404);
assert.equal((await request('/api/admin/responses', { cookie: adminCookie.slice(0, -1) + 'X' })).status, 401);
const toDelete = list.responses.find(row => row.agency === 'Agence Settat');
assert.equal((await request('/api/admin/delete', { method: 'POST', cookie: cookieA, body: { id: toDelete.id, updatedAt: toDelete.updatedAt } })).status, 401, 'A participant cannot delete an agency');
assert.equal((await request('/api/admin/delete', { method: 'POST', cookie: adminCookie, origin: 'https://other.test', body: { id: toDelete.id, updatedAt: toDelete.updatedAt } })).status, 403);
assert.equal((await request('/api/admin/delete', { method: 'POST', cookie: adminCookie, body: null })).status, 400);
assert.equal((await request('/api/admin/delete', { method: 'POST', cookie: adminCookie, body: { id: toDelete.id, updatedAt: '2000-01-01T00:00:00.000Z' } })).status, 409, 'A stale confirmation cannot delete an updated request');
assert.equal((await request('/api/admin/delete', { method: 'POST', cookie: adminCookie, body: { id: toDelete.id, updatedAt: toDelete.updatedAt } })).status, 200);
const afterDelete = await (await request('/api/admin/responses', { cookie: adminCookie })).json();
assert.equal(afterDelete.responses.length, 1);
assert.equal(afterDelete.responses[0].agency, 'Agence Casablanca', 'Other agencies must be preserved');
const remainingExport = new TextDecoder().decode(await (await request('/api/admin/export', { cookie: adminCookie })).arrayBuffer());
assert.match(remainingExport, /r="H10"[^>]*><v>2<\/v>/);
assert.ok(!remainingExport.includes('Agence Settat : 4'), 'Deleted agency data must not appear in the export');
assert.equal((await request('/api/admin/export?agency=' + encodeURIComponent(toDelete.id), { cookie: adminCookie })).status, 404);
assert.equal((await request('/api/admin/delete', { method: 'POST', cookie: adminCookie, body: { id: toDelete.id, updatedAt: toDelete.updatedAt } })).status, 409, 'A repeated delete must not affect another agency');
const remaining = afterDelete.responses[0];
assert.equal((await request('/api/admin/delete', { method: 'POST', cookie: adminCookie, body: { id: remaining.id, updatedAt: remaining.updatedAt } })).status, 200);
assert.equal((await request('/api/admin/export', { cookie: adminCookie })).status, 404, 'An empty collection must not export deleted data');
assert.equal((await request('/api/submit', { method: 'POST', cookie: cookieB, body: { agency: 'Agence Settat', items: [item(1, 'Nouvelle demande après suppression')] } })).status, 200, 'A removed agency can submit again');
const webOrigin = environment.PUBLIC_WEB_ORIGIN;
const preflight = await request('/api/submit', { method: 'OPTIONS', origin: webOrigin });
assert.equal(preflight.status, 204);
assert.equal(preflight.headers.get('access-control-allow-origin'), webOrigin);
assert.equal((await request('/api/session', { method: 'OPTIONS', origin: 'https://evil.test' })).status, 403);
const evil = await request('/api/session', { origin: 'https://univcours.github.io.evil.test' });
assert.equal(evil.status, 403);
assert.equal(evil.headers.get('access-control-allow-origin'), null);
const webSessionResponse = await request('/api/session', { origin: webOrigin });
assert.equal(webSessionResponse.headers.get('access-control-allow-origin'), webOrigin);
const webSession = await webSessionResponse.json();
assert.ok(webSession.participantToken);
const webAuth = 'Bearer ' + webSession.participantToken;
assert.equal((await request('/api/submit', { method: 'POST', origin: webOrigin, authorization: webAuth, body: { agency: 'Agence GitHub', items: [item(7, 'Saisie depuis GitHub Pages')] } })).status, 200);
const restoredWeb = await (await request('/api/session', { origin: webOrigin, authorization: webAuth })).json();
assert.equal(restoredWeb.submission.agency, 'Agence GitHub');
assert.equal((await request('/api/admin/responses', { origin: webOrigin, authorization: webAuth })).status, 401, 'A participant bearer token cannot authorize an admin operation');
assert.equal((await request('/api/admin/responses', { origin: webOrigin, cookie: adminCookie })).status, 401, 'Cross-origin calls do not inherit cookie-based admin access');
const webLogin = await request('/api/admin/login', { method: 'POST', origin: webOrigin, ip: 'web-admin', body: { password: environment.ADMIN_PASSWORD } });
const webAdmin = await webLogin.json();
assert.ok(webAdmin.adminToken);
const webAdminAuth = 'Bearer ' + webAdmin.adminToken;
const webList = await (await request('/api/admin/responses', { origin: webOrigin, authorization: webAdminAuth })).json();
assert.ok(webList.responses.some(row => row.agency === 'Agence GitHub'));
const webExport = await request('/api/admin/export', { origin: webOrigin, authorization: webAdminAuth });
assert.equal(webExport.status, 200);
assert.equal(webExport.headers.get('access-control-expose-headers'), 'Content-Disposition');
assert.match(new TextDecoder().decode(await webExport.arrayBuffer()), /Agence GitHub : 7 — Saisie depuis GitHub Pages/);
assert.equal((await request('/api/admin/responses', { origin: 'https://evil.test', authorization: webAdminAuth })).status, 403, 'A valid token still cannot be used from an unapproved browser origin');
const githubRow = webList.responses.find(row => row.agency === 'Agence GitHub');
assert.equal((await request('/api/admin/delete', { method: 'POST', origin: webOrigin, authorization: webAdminAuth, body: { id: githubRow.id, updatedAt: githubRow.updatedAt } })).status, 200);
const nativeSession = await (await request('/api/session', { cookie: cookieA })).json();
assert.equal(nativeSession.participantToken, undefined, 'The native site must not expose cookie sessions to its client JavaScript');
for (let attempt = 0; attempt < 10; attempt++) assert.equal((await request('/api/admin/login', { method: 'POST', ip: 'bruteforce', body: { password: 'wrong' } })).status, 401);
assert.equal((await request('/api/admin/login', { method: 'POST', ip: 'bruteforce', body: { password: environment.ADMIN_PASSWORD } })).status, 429);
sqlite.close();
console.log('PASS: accès privé, sessions, consolidation, suppression ciblée et protégée, prévention des suppressions périmées, retrait des exports et nouvel envoi après suppression.');
