import { COUNT_AGENCIES } from './count-agencies.mjs';
import { InputError } from './validation.mjs';
export const CONTROLE_MODULES = Object.freeze([
 {id:'bouclage_am',label:'Bouclage AM'},
 {id:'notification_enregistree',label:'Notification des envois enregistrés'},
 {id:'notification_recommandee',label:'Notification des envois recommandés'},
 {id:'hdg',label:'HDG'},
]);
export const CONTROLE_STATUSES = ['EN_ATTENTE','OK','ANOMALIE'];
export const normalizeAgency = s => String(s??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim();
export function chooseAgency(value) {
 const n=normalizeAgency(value);
 if(!n)return null;
 const exact=COUNT_AGENCIES.filter(a=>normalizeAgency(a)===n);
 if(exact.length===1)return exact[0];
 const trimmed=n.replace(/^(AGENCE|BUREAU|ABB|AP|DESTINATION) /,'');
 const matches=COUNT_AGENCIES.filter(a=>normalizeAgency(a)===trimmed);
 return matches.length===1?matches[0]:null;
}
export function validControleModule(id){return CONTROLE_MODULES.some(x=>x.id===id);}
export function cleanBarcode(value) {
 const raw=String(value??'').trim().replace(/[\u0000-\u001f\u007f]/g,'');
 if(!raw||raw.length>128||/[<>]/.test(raw))throw new InputError('Code-barres invalide (1 à 128 caractères).');
 return raw;
}
export function validateControleItems(module,items){
 if(!validControleModule(module))throw new InputError('Opération non reconnue.');
 if(!Array.isArray(items)||items.length<1||items.length>10000)throw new InputError('Le fichier doit contenir de 1 à 10 000 codes-barres.');
 const seen=new Set(),clean=[];
 for(const value of items){
  const agency=chooseAgency(value?.agency);
  if(!agency)throw new InputError('Agence inconnue : '+String(value?.agency??'').slice(0,60));
  const barcode=cleanBarcode(value?.barcode);
  const key=normalizeAgency(agency)+'|'+barcode.toUpperCase();
  if(seen.has(key))continue;
  seen.add(key);clean.push({agency,barcode});
 }
 return clean;
}
