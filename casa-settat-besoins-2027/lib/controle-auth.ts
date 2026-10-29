import { env } from 'cloudflare:workers';
import { cookieHeader, digest, readToken, signToken, trustedWebOrigin } from './security';

const d1=()=>{if(!env.DB)throw new Error('Base de données indisponible.');return env.DB;};
type AgencyAccount={
 agency_key:string; agency:string; username:string; username_key:string;
 password_hash:string; salt:string; password_iterations:number; active:number;
 credential_version:number; updated_at:string;
};
const enc=new TextEncoder();
const ALGORITHM_ITERATIONS=150000;
const base64url=(bytes:Uint8Array)=>btoa(String.fromCharCode(...bytes)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
const decodeBase64url=(s:string)=>Uint8Array.from(atob(s.replace(/-/g,'+').replace(/_/g,'/')),x=>x.charCodeAt(0));
export const usernameKey=(value:unknown)=>String(value??'').trim().normalize('NFKC').toLowerCase();
export const validUsername=(value:string)=>/^[a-z0-9][a-z0-9._-]{2,59}$/.test(value);
export const validPassword=(value:unknown)=>typeof value==='string'&&value.length>=10&&value.length<=128;
async function derive(password:string,salt:string,iterations=ALGORITHM_ITERATIONS){
 const key=await crypto.subtle.importKey('raw',enc.encode(password),'PBKDF2',false,['deriveBits']);
 const bits=await crypto.subtle.deriveBits({name:'PBKDF2',hash:'SHA-256',salt:decodeBase64url(salt),iterations},key,256);
 return base64url(new Uint8Array(bits));
}
export async function createPasswordHash(password:string){
 const salt=base64url(crypto.getRandomValues(new Uint8Array(16)));
 return {salt,hash:await derive(password,salt),iterations:ALGORITHM_ITERATIONS};
}
async function checkPassword(password:string,account:AgencyAccount){
 const computed=await derive(password,account.salt,account.password_iterations);
 if(computed.length!==account.password_hash.length)return false;
 let diff=0;for(let i=0;i<computed.length;i++)diff|=computed.charCodeAt(i)^account.password_hash.charCodeAt(i);
 return diff===0;
}
export async function isControleSiteOpen(){
 const row=await d1().prepare('SELECT is_open FROM controle_site_state WHERE id=1').first<{is_open:number}>();
 return row?.is_open===1;
}
export async function siteAvailability(){
 const row=await d1().prepare('SELECT is_open,updated_at FROM controle_site_state WHERE id=1')
  .first<{is_open:number;updated_at:string}>();
 return {open:row?.is_open===1,updatedAt:row?.updated_at||''};
}
export async function updateSiteAvailability(open:boolean){
 const date=new Date().toISOString();
 await d1().prepare('INSERT INTO controle_site_state (id,is_open,updated_at) VALUES (1,?,?) '+
  'ON CONFLICT(id) DO UPDATE SET is_open=excluded.is_open,updated_at=excluded.updated_at').bind(open?1:0,date).run();
 return {open,updatedAt:date};
}
export async function findAccountByUsername(username:string){
 return d1().prepare('SELECT * FROM controle_agency_accounts WHERE username_key=?').bind(username)
  .first<AgencyAccount>();
}
export async function listAgencyAccounts(){
 const rows=await d1().prepare('SELECT agency,agency_key,username,active,credential_version,updated_at '+
  'FROM controle_agency_accounts ORDER BY agency COLLATE NOCASE').all<Pick<AgencyAccount,'agency'|'agency_key'|'username'|'active'|'credential_version'|'updated_at'>>();
 return rows.results.map(row=>({agency:row.agency,username:row.username,active:!!row.active,updatedAt:row.updated_at}));
}
export async function writeAgencyAccount(agency:string,agencyKey:string,username:string,password:unknown,active:boolean){
 const key=usernameKey(username);
 if(!validUsername(key))throw Error('Identifiant invalide : 3 à 60 caractères (lettres, chiffres, point, tiret ou souligné).');
 const existing=await d1().prepare('SELECT * FROM controle_agency_accounts WHERE agency_key=?').bind(agencyKey).first<AgencyAccount>();
 if(!existing&&!validPassword(password))throw Error('Le mot de passe doit contenir entre 10 et 128 caractères.');
 if(password!==undefined&&password!==''&&!validPassword(password))throw Error('Mot de passe trop court : 10 caractères minimum.');
 const owner=await findAccountByUsername(key);
 if(owner&&owner.agency_key!==agencyKey)throw Error('Cet identifiant est déjà attribué à une autre agence.');
 const hashed=typeof password==='string'&&password!==''?await createPasswordHash(password):null;
 const stamp=new Date().toISOString();
 if(existing){
  await d1().prepare('UPDATE controle_agency_accounts SET agency=?,username=?,username_key=?,'+
   'password_hash=?,salt=?,password_iterations=?,active=?,credential_version=credential_version+1,updated_at=? WHERE agency_key=?')
   .bind(agency,username.trim(),key,hashed?.hash||existing.password_hash,hashed?.salt||existing.salt,
    hashed?.iterations||existing.password_iterations,active?1:0,stamp,agencyKey).run();
 }else{
  if(!hashed)throw Error('Mot de passe requis pour la nouvelle agence.');
  await d1().prepare('INSERT INTO controle_agency_accounts '+
   '(agency_key,agency,username,username_key,password_hash,salt,password_iterations,active,credential_version,updated_at) '+
   'VALUES (?,?,?,?,?,?,?,?,1,?)')
   .bind(agencyKey,agency,username.trim(),key,hashed.hash,hashed.salt,hashed.iterations,active?1:0,stamp).run();
 }
 return {agency,username:username.trim(),active,updatedAt:stamp};
}
export async function loginAgency(request:Request,username:unknown,password:unknown){
 const key=usernameKey(username);
 if(!validUsername(key)||typeof password!=='string'||password.length>128)
  return {error:'Identifiant ou mot de passe incorrect.',status:401} as const;
 const ip=request.headers.get('cf-connecting-ip')||'unknown';
 const attemptKey=await digest('agency-login:'+ip+':'+key+':'+Math.floor(Date.now()/900000));
 const attempt=await d1().prepare('INSERT INTO login_attempts (key,attempts,expires_at) VALUES (?,1,?) '+
  'ON CONFLICT(key) DO UPDATE SET attempts=attempts+1 RETURNING attempts')
  .bind(attemptKey,Date.now()+900000).first<{attempts:number}>();
 if((attempt?.attempts||0)>10)return {error:'Trop de tentatives. Réessayez dans 15 minutes.',status:429} as const;
 const user=await findAccountByUsername(key);
 if(!user||!user.active||!(await checkPassword(password,user)))return {error:'Identifiant ou mot de passe incorrect.',status:401} as const;
 await d1().prepare('DELETE FROM login_attempts WHERE key=?').bind(attemptKey).run();
 const subject=JSON.stringify({agencyKey:user.agency_key,version:user.credential_version,username:key});
 const token=await signToken('controle_agency',subject,28800);
 return {ok:true,username:user.username,agency:user.agency,token:trustedWebOrigin(request)?token:undefined,
  cookie:cookieHeader(request,'controle_agency',token,28800)} as const;
}
export async function currentAgencyAccount(request:Request){
 const raw=await readToken(request,'controle_agency','controle_agency');
 if(!raw)return null;
 try{
  const info=JSON.parse(raw);
  if(typeof info?.agencyKey!=='string'||typeof info?.version!=='number'||typeof info?.username!=='string')return null;
  const row=await d1().prepare('SELECT * FROM controle_agency_accounts WHERE agency_key=?')
   .bind(info.agencyKey).first<AgencyAccount>();
  if(!row||!row.active||row.credential_version!==info.version||row.username_key!==info.username)return null;
  return {agency:row.agency,agencyKey:row.agency_key,username:row.username,version:row.credential_version};
 }catch{return null;}
}
