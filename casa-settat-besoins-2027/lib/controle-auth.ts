import { env } from 'cloudflare:workers';
import { cookieHeader, digest, readToken, signToken, trustedWebOrigin } from './security';

const db=()=>{if(!env.DB)throw new Error('Base de données indisponible.');return env.DB;};
type LoginAccount={username:string;username_key:string;password_hash:string;salt:string;password_iterations:number;active:number;credential_version:number;updated_at:string};
type Assignment={agency:string;agency_key:string;username_key:string;active:number;updated_at:string};
const encoder=new TextEncoder(),ITERATIONS=150000;
const b64=(buf:Uint8Array)=>btoa(String.fromCharCode(...buf)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
const unb64=(s:string)=>Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')),v=>v.charCodeAt(0));
export const usernameKey=(s:unknown)=>String(s??'').trim().normalize('NFKC').toLowerCase();
const validLogin=(s:string)=>/^[a-z0-9][a-z0-9._-]{2,59}$/.test(s);
const validPassword=(p:unknown)=>typeof p==='string'&&p.length>=10&&p.length<=128;
async function pbkdf2(password:string,salt:string,iterations=ITERATIONS){
 const raw=await crypto.subtle.importKey('raw',encoder.encode(password),'PBKDF2',false,['deriveBits']);
 return b64(new Uint8Array(await crypto.subtle.deriveBits({name:'PBKDF2',salt:unb64(salt),iterations,hash:'SHA-256'},raw,256)));
}
async function hashPassword(password:string){
 const salt=b64(crypto.getRandomValues(new Uint8Array(16)));
 return {salt,hash:await pbkdf2(password,salt),iterations:ITERATIONS};
}
async function samePassword(password:string,account:LoginAccount){
 const expected=account.password_hash,got=await pbkdf2(password,account.salt,account.password_iterations);
 if(expected.length!==got.length)return false;
 let diff=0;for(let i=0;i<expected.length;i++)diff|=expected.charCodeAt(i)^got.charCodeAt(i);
 return diff===0;
}
async function account(username:string){
 return db().prepare('SELECT * FROM controle_auth_users WHERE username_key=?').bind(username).first<LoginAccount>();
}
async function assignedAgencies(username:string){
 const rows=await db().prepare('SELECT agency,agency_key FROM controle_auth_agencies WHERE username_key=? AND active=1 ORDER BY agency COLLATE NOCASE')
  .bind(username).all<Pick<Assignment,'agency'|'agency_key'>>();
 return rows.results;
}
export async function isControleSiteOpen(){
 const row=await db().prepare('SELECT is_open FROM controle_site_state WHERE id=1').first<{is_open:number}>();
 return row?.is_open===1;
}
export async function siteAvailability(){
 const row=await db().prepare('SELECT is_open,updated_at FROM controle_site_state WHERE id=1')
  .first<{is_open:number;updated_at:string}>();
 return {open:row?.is_open===1,updatedAt:row?.updated_at||''};
}
export async function updateSiteAvailability(open:boolean){
 const stamp=new Date().toISOString();
 await db().prepare('INSERT INTO controle_site_state (id,is_open,updated_at) VALUES (1,?,?) '+
   'ON CONFLICT(id) DO UPDATE SET is_open=excluded.is_open,updated_at=excluded.updated_at')
   .bind(open?1:0,stamp).run();
 return {open,updatedAt:stamp};
}
export async function listAgencyAccounts(){
 const rows=await db().prepare('SELECT m.agency,m.username_key,m.active,m.updated_at,a.username FROM controle_auth_agencies m '+
 'JOIN controle_auth_users a ON a.username_key=m.username_key ORDER BY a.username,m.agency COLLATE NOCASE')
 .all<{agency:string;username_key:string;active:number;updated_at:string;username:string}>();
 return rows.results.map(r=>({agency:r.agency,username:r.username,active:!!r.active,updatedAt:r.updated_at}));
}
export async function writeAgencyAccount(agency:string,agencyKey:string,username:string,password:unknown,active:boolean,changePassword=false){
 const key=usernameKey(username);
 if(!validLogin(key))throw Error('Identifiant invalide : 3 à 60 caractères (lettres, chiffres, point, tiret ou souligné).');
 if(password!==undefined&&password!==''&&!validPassword(password))throw Error('Mot de passe : 10 caractères minimum (128 maximum).');
 const [existing,assigned]=await Promise.all([
  account(key),db().prepare('SELECT username_key FROM controle_auth_agencies WHERE agency_key=?').bind(agencyKey)
    .first<{username_key:string}>()
 ]);
 if(!existing&&!validPassword(password))throw Error('Un mot de passe de 10 caractères minimum est nécessaire pour un nouvel identifiant.');
 if(changePassword&&!validPassword(password))throw Error('Nouveau mot de passe requis pour ce compte partagé.');
 // The same username always represents one password. Changing its password
 // is a deliberate, global rotation that revokes sessions for all agencies.
 const stamp=new Date().toISOString();
 if(!existing){
  const hash=await hashPassword(password as string);
  await db().prepare('INSERT INTO controle_auth_users '+
   '(username_key,username,password_hash,salt,password_iterations,active,credential_version,updated_at) '+
   'VALUES (?,?,?,?,?,1,1,?)')
   .bind(key,username.trim(),hash.hash,hash.salt,hash.iterations,stamp).run();
 }else if(changePassword){
  const hash=await hashPassword(password as string);
  await db().prepare('UPDATE controle_auth_users SET password_hash=?,salt=?,password_iterations=?,'+
   'credential_version=credential_version+1,updated_at=? WHERE username_key=?')
   .bind(hash.hash,hash.salt,hash.iterations,stamp,key).run();
 }else if(typeof password==='string'&&password!==''&&!(await samePassword(password,existing))){
  throw Error('Cet identifiant existe déjà avec un autre mot de passe. Pour changer celui du groupe, cochez « Changer le mot de passe du compte ».');
 }
 await db().prepare('INSERT INTO controle_auth_agencies (agency_key,agency,username_key,active,updated_at) VALUES (?,?,?,?,?) '+
  'ON CONFLICT(agency_key) DO UPDATE SET agency=excluded.agency,username_key=excluded.username_key,active=excluded.active,updated_at=excluded.updated_at')
  .bind(agencyKey,agency,key,active?1:0,stamp).run();
 if(assigned&&assigned.username_key!==key){
  // Assignment is checked afresh on every request, so the former account
  // loses this agency immediately even if it has a valid signed token.
  await db().prepare('UPDATE controle_auth_users SET credential_version=credential_version+1,updated_at=? WHERE username_key=?')
   .bind(stamp,assigned.username_key).run();
 }
 return {agency,username:username.trim(),active,updatedAt:stamp};
}
export async function loginAgency(request:Request,username:unknown,password:unknown){
 const key=usernameKey(username);
 if(!validLogin(key)||typeof password!=='string'||password.length>128)
  return {error:'Identifiant ou mot de passe incorrect.',status:401} as const;
 const ip=request.headers.get('cf-connecting-ip')||'shared';
 const attemptKey=await digest('agency-login:'+ip+':'+key+':'+Math.floor(Date.now()/900000));
 const attempt=await db().prepare('INSERT INTO login_attempts (key,attempts,expires_at) VALUES (?,1,?) '+
  'ON CONFLICT(key) DO UPDATE SET attempts=attempts+1 RETURNING attempts')
  .bind(attemptKey,Date.now()+900000).first<{attempts:number}>();
 if((attempt?.attempts||0)>10)return {error:'Trop de tentatives. Réessayez dans 15 minutes.',status:429} as const;
 const found=await account(key);
 if(!found||!found.active||!(await samePassword(password,found)))
  return {error:'Identifiant ou mot de passe incorrect.',status:401} as const;
 const agencies=await assignedAgencies(key);
 if(!agencies.length)return {error:'Ce compte ne possède aucune agence active.',status:403} as const;
 await db().prepare('DELETE FROM login_attempts WHERE key=?').bind(attemptKey).run();
 const subject=JSON.stringify({username:key,version:found.credential_version});
 const token=await signToken('controle_agency',subject,28800);
 return {ok:true,username:found.username,agencies:agencies.map(a=>a.agency),
   token:trustedWebOrigin(request)?token:undefined,
   cookie:cookieHeader(request,'controle_agency',token,28800)} as const;
}
export async function currentAgencyAccount(request:Request){
 const raw=await readToken(request,'controle_agency','controle_agency');
 if(!raw)return null;
 try{
  const info=JSON.parse(raw);
  if(typeof info?.username!=='string'||typeof info?.version!=='number')return null;
  const found=await account(info.username);
  if(!found||!found.active||found.credential_version!==info.version)return null;
  const assignments=await assignedAgencies(info.username);
  if(!assignments.length)return null;
  return {username:found.username,usernameKey:found.username_key,agencies:assignments.map(a=>a.agency),
   agencyKeys:assignments.map(a=>a.agency_key),version:found.credential_version};
 }catch{return null;}
}
