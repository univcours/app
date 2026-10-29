import { env } from 'cloudflare:workers';
import { COUNT_AGENCIES } from './count-agencies.mjs';
import { chooseAgency, validControleModule, validateControleItems, normalizeAgency } from './controle.mjs';
import { InputError, agencyKey } from './validation.mjs';
import { cookieHeader, digest, readToken, signToken, trustedWebOrigin } from './security';

type RecordRow = {id:string;module:string;agency:string;barcode:string;status:string;observation:string;active:number;file_name:string;created_at:string;updated_at:string;reviewed_at:string|null;reimport_count:number};
const json=(obj:unknown,status=200)=>Response.json(obj,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
const db=()=>{if(!env.DB)throw new Error('Base de données indisponible.');return env.DB;};
const serialize=(r:RecordRow)=>({id:r.id,module:r.module,agency:r.agency,barcode:r.barcode,status:r.status,observation:r.observation,source:r.file_name,updatedAt:r.updated_at,reviewedAt:r.reviewed_at,alreadyNotified:r.status==='OK'&&r.reimport_count>0});
const moduleFrom=(u:URL)=>{const m=u.searchParams.get('module')||'';if(!validControleModule(m))throw new InputError('Opération non reconnue.');return m;};
async function officialAgencies():Promise<string[]> {
 const rows=await db().prepare('SELECT name FROM controle_agencies ORDER BY name COLLATE NOCASE LIMIT 1000').all<{name:string}>();
 return [...new Set([...COUNT_AGENCIES,...rows.results.map(row=>row.name)])].sort((a,b)=>a.localeCompare(b,'fr'));
}

function csvCell(v:unknown){return '"'+String(v??'').replace(/"/g,'""').replace(/^[=+@\-]/,match=>"'"+match)+'"';}
export async function handleControle(request:Request,path:string):Promise<Response|null> {
 if(!path.startsWith('/api/controle/')&&!path.startsWith('/api/admin/controle/'))return null;
 const u=new URL(request.url),isAdminPath=path.startsWith('/api/admin/controle/');
 if(path==='/api/controle/health'&&request.method==='GET'){
  try{
   const database=db();
   await database.prepare('SELECT 1 FROM controle_codes LIMIT 1').first();
   await database.prepare('SELECT 1 FROM controle_acces LIMIT 1').first();
   await database.prepare('SELECT 1 FROM controle_agencies LIMIT 1').first();
   await database.prepare('SELECT reimport_count FROM controle_codes LIMIT 1').first();
   return json({ready:true});
  }catch{
   return json({ready:false,error:'Le service des codes-barres attend la mise à jour de la base de données.'},503);
  }
 }
 const admin=isAdminPath?await readToken(request,'budget_admin','admin'):null;
 if(isAdminPath&&!admin)return json({error:'Accès réservé au coordinateur.'},401);
 if(path==='/api/controle/agencies'&&request.method==='GET'){
  return json({agencies:await officialAgencies()});
 }
 if(path==='/api/admin/controle/agencies'&&request.method==='POST'){
  const raw=await request.text();
  if(raw.length>1000)return json({error:'Nom d’agence trop long.'},413);
  const data=JSON.parse(raw),name=String(data?.name??'').trim().replace(/\\s+/g,' ');
  const normalized=normalizeAgency(name);
  if(name.length<2||name.length>100||normalized.length<2||!/[A-Z]/.test(normalized)||/[<>\\u0000-\\u001f]/.test(name))
   return json({error:'Indiquez un nom d’agence valide (2 à 100 caractères).'},400);
  const already=chooseAgency(name,await officialAgencies());
  if(already)return json({error:'Cette agence existe déjà dans la liste principale : '+already},409);
  const result=await db().prepare('INSERT INTO controle_agencies (agency_key,name,created_at) VALUES (?,?,?) ON CONFLICT(agency_key) DO NOTHING')
   .bind(normalized,name,new Date().toISOString()).run();
  if(!result.meta.changes)return json({error:'Cette agence est déjà enregistrée.'},409);
  return json({ok:true,agency:name,agencies:await officialAgencies()});
 }
 if(path==='/api/controle/session'&&request.method==='GET'){
  let session=await readToken(request,'budget_participant','participant');
  if(!session)session=crypto.randomUUID();
  const token=await signToken('participant',session,31536000);
  const headers:{[key:string]:string}={'Cache-Control':'no-store','Set-Cookie':cookieHeader(request,'budget_participant',token,31536000)};
  return Response.json({ready:true,participantToken:trustedWebOrigin(request)?token:undefined},{headers});
 }
 if(path==='/api/controle/items'&&request.method==='GET'){
  if(!await readToken(request,'budget_participant','participant'))return json({error:'Session expirée. Rechargez la page.'},401);
  const module=moduleFrom(u),agency=chooseAgency(u.searchParams.get('agency'),await officialAgencies());
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
  const agency=chooseAgency(obj?.agency,await officialAgencies()),module=obj?.module;
  if(!agency||!validControleModule(module)||typeof obj?.id!=='string'||obj.id.length>100)return json({error:'Sélection invalide.'},400);
  if(!['OK','ANOMALIE'].includes(obj.status))return json({error:'Choisissez OK ou Anomalie.'},400);
  const observation=obj.status==='OK'?'':String(obj.observation??'').trim();
  if(obj.status==='ANOMALIE'&&(!observation||observation.length>500))return json({error:'Une observation de 1 à 500 caractères est obligatoire.'},400);
  const now=new Date().toISOString();
  const res=await db().prepare('UPDATE controle_codes SET status=?,observation=?,updated_at=?,reviewed_at=?,reviewer_session=? WHERE id=? AND module=? AND agency_key=? AND active=1 RETURNING id').bind(obj.status,observation,now,now,await digest(session),obj.id,module,agencyKey(agency)).first<{id:string}>();
  if(!res)return json({error:'Ce code a été retiré ou n’est pas disponible pour cette agence.'},409);
  return json({ok:true,id:res.id,status:obj.status,observation,updatedAt:now});
 }
 if(path==='/api/admin/controle/import'&&request.method==='POST'){
  const raw=await request.text();
  if(raw.length>2500000)return json({error:'Import trop volumineux (maximum 2,5 Mo).'},413);
  const obj=JSON.parse(raw),module=obj?.module;
  const scope=obj?.scope??'all';
  if(scope!=='all'&&scope!=='single')return json({error:'Mode d’importation non reconnu.'},400);
  const agencies=await officialAgencies();
  const items=validateControleItems(module,obj?.items,agencies);
  const selected=scope==='single'?chooseAgency(obj?.agency,agencies):null;
  if(scope==='single'&&!selected)return json({error:'Sélectionnez une agence valide.'},400);
  if(selected&&items.some(item=>item.agency!==selected))
    return json({error:'Ce fichier contient des codes destinés à une autre agence. Importation refusée.'},400);
  const fileName=String(obj.fileName??'Import Excel').replace(/[\u0000-\u001f<>]/g,'').slice(0,180);
  const now=new Date().toISOString();
  // One transactional batch. Global: refresh one operation, all agencies.
  // Single: refresh ONLY the selected agency in that operation.
  const statements=scope==='single'
   ? [db().prepare('UPDATE controle_codes SET active=0 WHERE module=? AND agency_key=?').bind(module,agencyKey(selected!))]
   : [db().prepare('UPDATE controle_codes SET active=0 WHERE module=?').bind(module)];
  // D1 permits 100 bound values per statement. A JSON row batch keeps the
  // entire supported 10,000-code import below 50 database statements, while
  // preserving the single transaction and existing review results.
  for(let start=0;start<items.length;start+=250){
   const batch=items.slice(start,start+250).map(item=>({id:crypto.randomUUID(),agency:item.agency,agencyKey:agencyKey(item.agency),barcode:item.barcode}));
   const jsonSql='INSERT INTO controle_codes (id,module,agency,agency_key,barcode,status,observation,active,file_name,created_at,updated_at) '+
    "SELECT json_extract(value,'$.id'), ?, json_extract(value,'$.agency'), json_extract(value,'$.agencyKey'), json_extract(value,'$.barcode'), 'EN_ATTENTE', '', 1, ?, ?, ? FROM json_each(?) WHERE 1 "+
    'ON CONFLICT(module,agency_key,barcode) DO UPDATE SET active=1,agency=excluded.agency,file_name=excluded.file_name,reimport_count=controle_codes.reimport_count+CASE WHEN controle_codes.status='OK' THEN 1 ELSE 0 END';
   statements.push(db().prepare(jsonSql).bind(module,fileName,now,now,JSON.stringify(batch)));
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
  const csv='\ufeff'+[header,...rows.results.map(r=>[r.module,r.agency,r.barcode,r.status==='OK'&&r.reimport_count>0?'Déjà notifié':r.status,r.observation,r.reviewed_at??'',r.file_name])]
   .map(row=>row.map(csvCell).join(';')).join('\r\n');
  return new Response(csv,{headers:{'Content-Type':'text/csv; charset=utf-8','Content-Disposition':'attachment; filename="controle_'+module+'.csv"','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
 }
 return json({error:'Ressource introuvable.'},404);
}
