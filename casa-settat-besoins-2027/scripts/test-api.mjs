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
for (const file of (await fs.readdir(path.join(root,'drizzle'))).filter(file=>file.endsWith('.sql')).sort()) sqlite.exec(await fs.readFile(path.join(root,'drizzle',file),'utf8'));
function prepared(sql, bindings = []) {
  assert.ok(bindings.length <= 100, 'D1 limits each SQL statement to 100 bound parameters');
  return {
    bind(...args) { return prepared(sql, args); },
    async first() { return sqlite.prepare(sql).get(...bindings) || null; },
    async all() { return { results: sqlite.prepare(sql).all(...bindings), success: true }; },
    async run() { const result=sqlite.prepare(sql).run(...bindings); return {success:true,meta:{changes:Number(result.changes)}}; },
  };
}
const environment = { DB: { prepare: sql => prepared(sql), async batch(statements) { assert.ok(statements.length<=50,'An import must fit even the 50-query invocation budget'); sqlite.exec('BEGIN'); try { const result = []; for (const statement of statements) result.push(await statement.all()); sqlite.exec('COMMIT'); return result; } catch (error) { sqlite.exec('ROLLBACK'); throw error; } } }, SESSION_SECRET: 'test-only-session-secret-with-more-than-32-characters', ADMIN_PASSWORD: 'test-only-not-a-production-password', PUBLIC_WEB_ORIGIN: 'https://univcours.github.io' };
const context = vm.createContext({ Request, Response, URL, TextEncoder, TextDecoder, Uint8Array, DataView, crypto: webcrypto, btoa, atob, console });
const cache = new Map();
const synthetic = (identifier, exports) => new vm.SyntheticModule(Object.keys(exports), function() { for (const [key, value] of Object.entries(exports)) this.setExport(key, value); }, { context, identifier });
async function load(identifier) {
  if (cache.has(identifier)) return cache.get(identifier);
  // Shared imports can be linked concurrently. Cache the in-flight load so
  // validation errors keep the same class identity in every route module.
  const loading = (async () => {
  let module;
  if (identifier === 'cloudflare:workers') module = synthetic(identifier, { env: environment });
  else if (identifier === 'node:zlib') module = synthetic(identifier, { inflateRawSync });
  else if (identifier.endsWith('.json')) module = synthetic(identifier, { default: JSON.parse(await fs.readFile(identifier, 'utf8')) });
  else {
    const source = await fs.readFile(identifier, 'utf8');
    const code = identifier.endsWith('.ts') ? ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText : source;
    module = new vm.SourceTextModule(code, { context, identifier });
  }
  return module;
  })();
  cache.set(identifier, loading); return loading;
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
// The monthly counting module shares authorization, but owns separate records.
const needsBeforeCounts = sqlite.prepare('SELECT COUNT(*) AS n FROM submissions').get().n;
const countValues = (a=1,b=0) => [a,b,...Array(12).fill(null)];
const countBody = {agency:'Agence Comptage',month:'2026-11',rows:[{date:'2026-11-02',frequency:5,values:countValues(12,0)}]};
assert.equal((await request('/api/admin/comptage/responses?month=2026-11')).status,401);
assert.equal((await request('/api/admin/comptage/export?month=2026-11')).status,401);
assert.equal((await request('/api/comptage/submit',{method:'POST',body:countBody})).status,401);
assert.equal((await request('/api/comptage/session?month=2026-13')).status,400);
const countSession=await request('/api/comptage/session?month=2026-11&agency=Agence%20Comptage',{origin:webOrigin});
const countToken=(await countSession.json()).participantToken;
assert.ok(countToken);const countAuth='Bearer '+countToken;
const postCount=body=>request('/api/comptage/submit',{method:'POST',origin:webOrigin,authorization:countAuth,body});
assert.equal((await postCount({...countBody,rows:[{...countBody.rows[0],frequency:null}]})).status,400);
assert.equal((await postCount({...countBody,rows:[{...countBody.rows[0],values:countValues(-1)}]})).status,400);
assert.equal((await postCount({...countBody,rows:[{...countBody.rows[0],values:countValues(1.5)}]})).status,400);
assert.equal((await postCount(countBody)).status,200);
const updatedCount=await postCount({...countBody,rows:[{date:'2026-11-02',frequency:5,values:countValues(14,0)},{date:'2026-11-30',frequency:2,values:countValues(2,1)}]});
assert.equal(updatedCount.status,200);const countReceipt=await updatedCount.json();
assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM count_submissions').get().n,1,'Replacing an agency month must not duplicate it');
const ownedCount=await (await request('/api/comptage/session?month=2026-11&agency=Agence%20Comptage',{origin:webOrigin,authorization:countAuth})).json();
assert.equal(ownedCount.submission.rows[0].values[0],14);assert.equal(ownedCount.submission.rows[0].values[1],0);assert.equal(ownedCount.submission.rows[0].values[2],null);
assert.equal((await request('/api/comptage/submit',{method:'POST',cookie:cookieA,body:countBody})).status,409,'Another browser must not overwrite an agency month');
assert.equal((await postCount({...countBody,month:'2026-12',rows:[{date:'2026-12-01',frequency:3,values:countValues(7)}]})).status,200);
assert.equal((await postCount({...countBody,agency:'Deuxième agence'})).status,200);
const countList=await (await request('/api/admin/comptage/responses?month=2026-11',{origin:webOrigin,authorization:webAdminAuth})).json();
assert.equal(countList.responses.length,2);assert.deepEqual(countList.months,['2026-12','2026-11']);
const december=await (await request('/api/admin/comptage/responses?month=2026-12',{origin:webOrigin,authorization:webAdminAuth})).json();
assert.equal(december.responses.length,1);assert.equal(december.responses[0].rows[0].values[0],7,'Month isolation must preserve another month');
assert.equal((await request('/api/admin/comptage/responses?month=2026-11',{origin:webOrigin,authorization:countAuth})).status,401);
const countExport=await request('/api/admin/comptage/export?month=2026-11',{origin:webOrigin,authorization:webAdminAuth});
assert.equal(countExport.status,200);const countXml=new TextDecoder().decode(await countExport.arrayBuffer());
assert.match(countXml,/xl\/worksheets\/sheet2.xml/);assert.match(countXml,/<x:v>16<\/x:v>/);
assert.equal((await request('/api/admin/comptage/export?month=2026-10',{origin:webOrigin,authorization:webAdminAuth})).status,404);
assert.equal((await request('/api/admin/comptage/export?month=2026-12&agency='+countReceipt.id,{origin:webOrigin,authorization:webAdminAuth})).status,404,'Export scope must enforce both agency and month');
assert.equal((await request('/api/admin/comptage/delete',{method:'POST',origin:webOrigin,authorization:countAuth,body:countReceipt})).status,401);
assert.equal((await request('/api/admin/comptage/delete',{method:'POST',origin:webOrigin,authorization:webAdminAuth,body:{...countReceipt,updatedAt:'2000-01-01T00:00:00.000Z'}})).status,409);
assert.equal((await request('/api/admin/comptage/delete',{method:'POST',origin:webOrigin,authorization:webAdminAuth,body:countReceipt})).status,200);
assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM count_submissions WHERE month=?').get('2026-12').n,1,'Deleting November must preserve December');
assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM submissions').get().n,needsBeforeCounts,'Counting operations must preserve the existing needs records');
// Barcode-control routes use only additive migrations and isolated test data.
const legacyBefore = JSON.stringify({needs:sqlite.prepare('SELECT * FROM submissions ORDER BY id').all(),counts:sqlite.prepare('SELECT * FROM count_submissions ORDER BY id').all()});
const controlModules=['bouclage_am','notification_enregistree','notification_recommandee','hdg'];
assert.equal((await request('/api/controle/health',{origin:webOrigin})).status,200);
assert.equal((await (await request('/api/controle/health',{origin:webOrigin})).json()).ready,true);
const controlPreflight=await request('/api/admin/controle/aliases',{method:'OPTIONS',origin:webOrigin});
assert.match(controlPreflight.headers.get('access-control-allow-methods'),/DELETE/);
for(const op of controlModules)assert.equal((await request('/api/admin/controle/summary?module='+op,{origin:webOrigin})).status,401);
assert.equal((await request('/api/controle/items?module=hdg&agency=AFOURER',{origin:webOrigin})).status,401);
const controlSession=await (await request('/api/controle/session',{origin:webOrigin})).json();
const participantControl='Bearer '+controlSession.participantToken;
const controlRequest=(path,options={})=>request(path,{origin:webOrigin,authorization:webAdminAuth,...options});
assert.equal((await controlRequest('/api/admin/controle/summary?module=wrong')).status,400);
for(const op of controlModules){
 const body={module:op,fileName:'Import CAB NomAgence 0002.xlsx',scope:'all',items:[{agency:'AFOURER',barcode:'00001234'},{agency:'BNI AYAT',barcode:'OTHER-'+op}]};
 assert.equal((await controlRequest('/api/admin/controle/import',{method:'POST',body,authorization:participantControl})).status,401);
 const imported=await controlRequest('/api/admin/controle/import',{method:'POST',body});
 assert.equal(imported.status,200);assert.equal((await imported.json()).imported,2);
 const data=await (await controlRequest('/api/controle/items?module='+op+'&agency=AFOURER',{authorization:participantControl})).json();
 assert.equal(data.items.length,1);assert.equal(data.items[0].barcode,'00001234');
 assert.equal(data.items[0].source,body.fileName,'Original filenames and leading-zero barcodes must survive import');
 assert.equal((await controlRequest('/api/controle/review',{method:'POST',authorization:participantControl,body:{module:op,agency:'BNI AYAT',id:data.items[0].id,status:'OK'}})).status,409,'An agency cannot review another agency’s code');
 assert.equal((await controlRequest('/api/controle/review',{method:'POST',authorization:participantControl,body:{module:op,agency:'AFOURER',id:data.items[0].id,status:'ANOMALIE',observation:''}})).status,400);
 assert.equal((await controlRequest('/api/controle/review',{method:'POST',authorization:participantControl,body:{module:op,agency:'AFOURER',id:data.items[0].id,status:'ANOMALIE',observation:'À vérifier'}})).status,200);
 // Refreshing a file must retain the existing review of the same CAB.
 assert.equal((await controlRequest('/api/admin/controle/import',{method:'POST',body})).status,200);
 let restored=await (await controlRequest('/api/controle/items?module='+op+'&agency=AFOURER',{authorization:participantControl})).json();
 assert.equal(restored.items[0].status,'ANOMALIE');assert.equal(restored.items[0].observation,'À vérifier');
 const summary=await (await controlRequest('/api/admin/controle/summary?module='+op)).json();
 assert.ok(summary.summary.some(row=>row.agency==='AFOURER'&&row.status==='ANOMALIE'&&row.quantity===1));
 assert.ok(summary.accesses.some(row=>row.agency==='AFOURER'&&row.accessCount>=2));
 const csv=await (await controlRequest('/api/admin/controle/export?module='+op)).text();
 assert.match(csv,/00001234/);assert.match(csv,/À vérifier/);
 const wrongScope={...body,scope:'single',agency:'AFOURER'};
 assert.equal((await controlRequest('/api/admin/controle/import',{method:'POST',body:wrongScope})).status,400);
 const single={...body,scope:'single',agency:'AFOURER',items:[{agency:'AFOURER',barcode:'NEW-'+op}]};
 assert.equal((await controlRequest('/api/admin/controle/import',{method:'POST',body:single})).status,200);
 const otherAgency=await (await controlRequest('/api/controle/items?module='+op+'&agency=BNI%20AYAT',{authorization:participantControl})).json();
 assert.equal(otherAgency.items.length,1,'A single-agency import must preserve the other agencies');
 assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM controle_codes WHERE module=? AND barcode=?').get(op,'00001234').n,1,'Old codes are retained rather than deleted');
}
const aliasBody={items:[{alias:'Ait Attab',agency:'KHMISS OULED AYAD'}]};
assert.equal((await controlRequest('/api/admin/controle/aliases',{method:'POST',body:aliasBody})).status,200);
let aliases=await (await controlRequest('/api/admin/controle/aliases')).json();
assert.equal(aliases.aliases.find(row=>row.alias==='AIT ATTAB').agency,'KHMISS OULED AYAD');
assert.equal((await controlRequest('/api/admin/controle/aliases',{method:'POST',body:{items:[{alias:'Ait Attab',agency:'AÎT ATTAB'}]}})).status,200);
aliases=await (await controlRequest('/api/admin/controle/aliases')).json();
assert.equal(aliases.aliases.find(row=>row.alias==='AIT ATTAB').agency,'AÎT ATTAB','Alias corrections must replace the mapping, not duplicate it');
assert.equal((await controlRequest('/api/admin/controle/aliases?alias=AIT%20ATTAB',{method:'DELETE',origin:'https://evil.test'})).status,403);
assert.equal((await controlRequest('/api/admin/controle/aliases?alias=AIT%20ATTAB',{method:'DELETE'})).status,200);
// Import the documented maximum under real D1 parameter and query budgets.
const largeItems=Array.from({length:10000},(_,index)=>({agency:'AFOURER',barcode:'BULK-'+String(index).padStart(6,'0')}));
const largeImport=await controlRequest('/api/admin/controle/import',{method:'POST',body:{module:'hdg',scope:'single',agency:'AFOURER',fileName:'HDG CAB NomAgence.xlsx',items:largeItems}});
assert.equal(largeImport.status,200);assert.equal((await largeImport.json()).imported,10000);
const bulkBefore=sqlite.prepare('SELECT COUNT(*) AS n FROM controle_codes WHERE module=? AND active=1').get('hdg').n;
sqlite.exec("CREATE TRIGGER fail_control_import BEFORE INSERT ON controle_codes WHEN NEW.barcode='ROLLBACK' BEGIN SELECT RAISE(ABORT,'test import rollback'); END");
const failedImport=await controlRequest('/api/admin/controle/import',{method:'POST',body:{module:'hdg',scope:'all',items:[{agency:'AFOURER',barcode:'ROLLBACK'}]}});
assert.equal(failedImport.status,503);
assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM controle_codes WHERE module=? AND active=1').get('hdg').n,bulkBefore,'A failed import must roll back deactivation and keep the previous file active');
sqlite.exec('DROP TRIGGER fail_control_import');
assert.equal(JSON.stringify({needs:sqlite.prepare('SELECT * FROM submissions ORDER BY id').all(),counts:sqlite.prepare('SELECT * FROM count_submissions ORDER BY id').all()}),legacyBefore,'All previous needs and monthly count data must remain byte-for-byte unchanged');
for(const file of ['0002_controle_codes.sql','0003_controle_acces.sql','0004_controle_agency_aliases.sql'])sqlite.exec(await fs.readFile(path.join(root,'drizzle',file),'utf8'));
assert.equal(sqlite.prepare('SELECT COUNT(*) AS n FROM controle_codes WHERE module=? AND active=1').get('hdg').n,bulkBefore,'Reapplying additive migration SQL must not erase data');
console.log('PASS: four control operations, CAB/agency routing, global/single imports, 10,000 codes within D1 limits, review preservation, aliases, CORS, transactional rollback and legacy data preservation.');
sqlite.close();
console.log('PASS: comptage mensuel, agence, brouillons restaurés, export, rôles, séparation des mois et conservation des besoins 2027.');
console.log('PASS: accès privé, sessions, consolidation, suppression ciblée et protégée, prévention des suppressions périmées, retrait des exports et nouvel envoi après suppression.');
