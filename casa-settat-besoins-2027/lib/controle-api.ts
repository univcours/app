import { env } from 'cloudflare:workers';
import { COUNT_AGENCIES } from './count-agencies.mjs';
import { chooseAgency, cleanBarcode, validControleModule, validateControleItems, normalizeAgency } from './controle.mjs';
import { agencyKey } from './validation.mjs';
import { cookieHeader, digest, readToken, signToken, trustedWebOrigin } from './security';

type RecordRow = {id:string;module:string;agency:string;barcode:string;status:string;observation:string;active:number;file_name:string;created_at:string;updated_at:string;reviewed_at:string|null};
const json=(obj:unknown,status=200)=>Response.json(obj,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
const db=()=>{if(!env.DB)throw new Error('Base de données indisponible.');return env.DB;};
const serialize=(r:RecordRow)=>({id:r.id,module:r.module,agency:r.agency,barcode:r.barcode,status:r.status,observation:r.observation,source:r.file_name,updatedAt:r.updated_at,reviewedAt:r.reviewed_at});
const moduleFrom=(u:URL)=>{const m=u.searchParams.get('module')||'';if(!validControleModule(m))throw Error('Opération non reconnue.');return m;};
function csvCell(v:unknown){return '"'+String(v??'').replace(/"/g,'""').replace(/^[=+@\-]/,match=>"'"+match)+'"';}
export async function handleControle(request:Request,path:string):Promise<Response|null> {
 if(!path.startsWith('/api/controle/')&&!path.startsWith('/api/admin/controle/'))return null;
 const u=new URL(request.url),isAdminPath=path.startsWith('/api/admin/controle/');
 const admin=isAdminPath?await readToken(request,'budget_admin','admin'):null;
 if(isAdminPath&&!admin)return json({error:'Accès réservé au coordinateur.'},401);
 if(path==='/api/controle/session'&&request.method==='GET'){
  let session=await readToken(request,'budget_participant','participant');
  if(!session)session=crypto.randomUUID();
  const token=await signToken('participant',session,31536000);
  const headers:{[key:string]:string}={'Cache-Control':'no-store','Set-Cookie':cookieHeader(request,'budget_participant',token,31536000)};
  return Response.json({ready:true,participantToken:trustedWebOrigin(request)?token:undefined},{headers});
 }
 if(path==='/api/controle/items'&&request.method==='GET'){
  if(!await readToken(request,'budget_participant','participant'))return json({error:'Session expirée. Rechargez la page.'},401);
  const module=moduleFrom(u),agency=chooseAgency(u.searchParams.get('agency'));
  if(!agency)return json({error:'Sélectionnez une agence valide.'},400);
  const result=await db().prepare('SELECT * FROM controle_codes WHERE module=? AND agency_key=? AND active=1 ORDER BY barcode COLLATE NOCASE LIMIT 10001').bind(module,agencyKey(agency)).all<RecordRow>();
  if(result.results.length>10000)return json({error:'Trop de codes pour une seule agence.'},413);
  // Une ouverture est comptée uniquement après la sélection de l'agence et
  // l'affichage réussi de sa liste, même lorsque cette liste est vide.
  // Ce compteur mesure des consultations, pas l'identité d'un agent.
  const openedAt=new Date().toISOString();
  await db().prepare(
    'INSERT INTO controle_acces (module,agency,agency_key,first_access_at,last_access_at,access_count) VALUES (?,?,?,?,?,1) '+
    'ON CONFLICT(module,agency_key) DO UPDATE SET last_access_at=excluded.last_access_at,access_count=controle_acces.access_count+1'
  ).bind(module,agency,agencyKey(agency),openedAt,openedAt).run();
  return json({module,agency,items:result.results.map(serialize)});
 }
 if(path==='/api/controle/review'&&request.method==='POST'){
  const session=await readToken(request,'budget_participant','participant');
  if(!session)return json({error:'Session expirée. Rechargez la page.'},401);
  const body=await request.text();
  if(body.length>3000)return json({error:'Demande trop longue.'},413);
  const obj=JSON.parse(body);
  const agency=chooseAgency(obj?.agency),module=obj?.module;
  if(!agency||!validControleModule(module)||typeof obj?.id!=='string'||obj.id.length>100)return json({error:'Sélection invalide.'},400);
  if(!['OK','ANOMALIE'].includes(obj.status))return json({error:'Choisissez OK ou Anomalie.'},400);
  const observation=obj.status==='OK'?'':String(obj.observation??'').trim();
  if(obj.status==='ANOMALIE'&&(!observation||observation.length>500))return json({error:'Une observation de 1 à 500 caractères est obligatoire.'},400);
  const now=new Date().toISOString();
  const res=await db().prepare('UPDATE controle_codes SET status=?,observation=?,updated_at=?,reviewed_at=?,reviewer_session=? WHERE id=? AND module=? AND agency_key=? AND active=1 RETURNING id').bind(obj.status,observation,now,now,await digest(session),obj.id,module,agencyKey(agency)).first<{id:string}>();
  if(!res)return json({error:'Ce code a été retiré ou n’est pas disponible pour cette agence.'},409);
  return json({ok:true,id:res.id,status:obj.status,observation,updatedAt:now});
 }
 if(path==='/api/admin/controle/aliases'&&request.method==='GET'){
  const result=await db().prepare('SELECT alias_key,agency FROM controle_agency_aliases ORDER BY alias_key LIMIT 5000').all<{alias_key:string;agency:string}>();
  return json({aliases:result.results.map(({alias_key,agency})=>({alias:alias_key,agency}))});
 }
 if(path==='/api/admin/controle/aliases'&&request.method==='POST'){
  const raw=await request.text();
  if(raw.length>45000)return json({error:'Liste d’associations trop longue.'},413);
  const body=JSON.parse(raw);
  if(!Array.isArray(body?.items)||body.items.length<1||body.items.length>150)
   return json({error:'Veuillez transmettre entre 1 et 150 associations.'},400);
  const pairs=new Map<string,string>();
  for(const item of body.items){
   if(typeof item?.alias!=='string'||item.alias.length>150)return json({error:'Nom de destination invalide.'},400);
   const alias=normalizeAgency(item.alias),agency=chooseAgency(item?.agency);
   if(!alias||alias.length>150||!agency)return json({error:'Association de destination invalide.'},400);
   pairs.set(alias,agency);
  }
  const now=new Date().toISOString();
  await db().batch([...pairs].map(([alias,agency])=>
   db().prepare('INSERT INTO controle_agency_aliases (alias_key,agency,updated_at) VALUES (?,?,?) '+
   'ON CONFLICT(alias_key) DO UPDATE SET agency=excluded.agency,updated_at=excluded.updated_at')
   .bind(alias,agency,now)));
  return json({ok:true,saved:pairs.size});
 }
 if(path==='/api/admin/controle/aliases'&&request.method==='DELETE'){
  const supplied=u.searchParams.get('alias');
  if(!supplied||supplied.length>150)return json({error:'Nom de destination invalide.'},400);
  const key=normalizeAgency(supplied);
  if(!key||key.length>150)return json({error:'Nom de destination invalide.'},400);
  const deleted=await db().prepare('DELETE FROM controle_agency_aliases WHERE alias_key=?').bind(key).run();
  return json({ok:true,deleted:deleted.meta.changes||0});
 }
 if(path==='/api/admin/controle/import'&&request.method==='POST'){
  const raw=await request.text();
  if(raw.length>2500000)return json({error:'Import trop volumineux (maximum 2,5 Mo).'},413);
  const obj=JSON.parse(raw),module=obj?.module;
  const scope=obj?.scope??'all';
  if(scope!=='all'&&scope!=='single')return json({error:'Mode d’importation non reconnu.'},400);
  const items=validateControleItems(module,obj?.items);
  const selected=scope==='single'?chooseAgency(obj?.agency):null;
  if(scope==='single'&&!selected)return json({error:'Sélectionnez une agence valide.'},400);
  if(selected&&items.some(item=>item.agency!==selected))
    return json({error:'Ce fichier contient des codes destinés à une autre agence. Importation refusée.'},400);
  const fileName=String(obj.fileName??'Import Excel').replace(/[\\u0000-\\u001f<>]/g,'').slice(0,180);
  const now=new Date().toISOString();
  // One transactional batch. Global: refresh one operation, all agencies.
  // Single: refresh ONLY the selected agency in that operation.
  const statements=scope==='single'
   ? [db().prepare('UPDATE controle_codes SET active=0 WHERE module=? AND agency_key=?').bind(module,agencyKey(selected!))]
   : [db().prepare('UPDATE controle_codes SET active=0 WHERE module=?').bind(module)];
  for(let start=0;start<items.length;start+=30){
   const batch=items.slice(start,start+30);
   const sql='INSERT INTO controle_codes (id,module,agency,agency_key,barcode,status,observation,active,file_name,created_at,updated_at) VALUES '+
    batch.map(()=>' (?,?,?,?,?,?,?,?,?,?,?)').join(',')+
    ' ON CONFLICT(module,agency_key,barcode) DO UPDATE SET active=1,agency=excluded.agency,file_name=excluded.file_name';
   const args=batch.flatMap(item=>[crypto.randomUUID(),module,item.agency,agencyKey(item.agency),item.barcode,'EN_ATTENTE','',1,fileName,now,now]);
   statements.push(db().prepare(sql).bind(...args));
  }
  await db().batch(statements);
  const totals=new Map<string,number>();
  for(const item of items)totals.set(item.agency,(totals.get(item.agency)||0)+1);
  return json({ok:true,module,scope,agency:selected,imported:items.length,
    agencies:[...totals].map(([agency,count])=>({agency,count}))});
 }
 if(path==='/api/admin/controle/summary'&&request.method==='GET'){
  const module=moduleFrom(u);
  const rows=await db().prepare('SELECT agency, status, COUNT(*) AS quantity FROM controle_codes WHERE module=? AND active=1 GROUP BY agency,status ORDER BY agency').bind(module).all<{agency:string;status:string;quantity:number}>();
  const visits=await db().prepare('SELECT agency,first_access_at,last_access_at,access_count FROM controle_acces WHERE module=? ORDER BY agency').bind(module).all<{agency:string;first_access_at:string;last_access_at:string;access_count:number}>();
  return json({module,summary:rows.results,accesses:visits.results.map(row=>({
   agency:row.agency,firstAccessAt:row.first_access_at,lastAccessAt:row.last_access_at,accessCount:row.access_count
  }))});
 }
 if(path==='/api/admin/controle/export'&&request.method==='GET'){
  const module=moduleFrom(u);
  const rows=await db().prepare('SELECT * FROM controle_codes WHERE module=? AND active=1 ORDER BY agency,barcode').bind(module).all<RecordRow>();
  const header=['Opération','Agence','Code-barres','Statut','Observation','Date du contrôle','Fichier source'];
  const csv='\ufeff'+[header,...rows.results.map(r=>[r.module,r.agency,r.barcode,r.status,r.observation,r.reviewed_at??'',r.file_name])]
   .map(row=>row.map(csvCell).join(';')).join('\r\n');
  return new Response(csv,{headers:{'Content-Type':'text/csv; charset=utf-8','Content-Disposition':'attachment; filename="controle_'+module+'.csv"','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
 }
 return json({error:'Ressource introuvable.'},404);
}
