'use strict';
let AGENCES=["AFOURER","BNI AYAT","AÎT ATTAB","TAOUNZA AP","ARBAA AOUNAT","AZEMMOUR","AZILAL","BEJÂAD","BEN AHMED","BNI KHLOUG","GUISSER","BIR JDID","BOUJNIBA","BOULANOUAR","BZOU","DAR OULED ZIDOUH","DEMNATE","EL BOROUJ","RAS EL AIN","OULED ABBOU","EL GARA","EL KSIBA","AGHBALA","FOUM EL ANSER","TAGHZIRT","FOUM JEMÂA","HAD BRADIA","HAD SOUALEM","SIDI RAHAL PLAGE","SOUALEM TRIFIA","HATTANE","KHMISS OULED AYAD","KHMISS ZMAMRA","MLY ABDELLAH","SIDI BOUZID","OUALIDIA","OUAOUIZAGHT","OULED FREJ","OULED M'BAREK","FOUM OUDI","LÂAYAYTA AP","OULED YAÎCH","SIDI BENNOUR","SIDI HAJJAJ","SIDI JABER","SIDI ISMAIL","SOUK TLAT LOULAD","TNIN GHARBIA","ZAOUIA ECHCHEIKH"];
const MODULES={bouclage_am:'Bouclage AM',notification_enregistree:'Notification des envois enregistrés',notification_recommandee:'Notification des envois recommandés',hdg:'HDG'};
const BASE=window.__UNIVCOURS_API_BASE__||'https://besoin2027.hamidtawfiq2.chatgpt.site';
let controleServiceReady=false;
const unavailableNotice='Service des codes-barres non activé sur le serveur : import Excel, validation OK/Anomalie et suivi partagé indisponibles. La mise à jour de l’API et de la base de données doit être publiée.';
async function verifyControleService(){
 const el=document.getElementById('service-state');
 try{
  const response=await fetch(BASE+'/api/controle/health',{method:'GET',mode:'cors',credentials:'omit',cache:'no-store'});
  const body=await response.json().catch(()=>({}));
  if(!response.ok||body.ready!==true)throw Error(body.error||unavailableNotice);
  controleServiceReady=true;
  el?.classList.add('hidden');
 }catch(error){
  controleServiceReady=false;
  if(el){
   el.textContent=unavailableNotice;
   el.classList.remove('hidden');
  }
 }
 if(document.getElementById('import-preview'))refreshImportPreview();
}
const $=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const normal=s=>String(s??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim();
const agencyFor=value=>{const n=normal(value),simple=n.replace(/^(AGENCE|BUREAU|ABB|AP|DESTINATION) /,'');return AGENCES.find(a=>normal(a)===n)||AGENCES.find(a=>normal(a)===simple)||null};
const ALIAS_STORAGE='controle-agency-associations-v1';
let moduleId='bouclage_am',agentItems=[],filteredItems=[],recordIndex=0,admin=false,books=[],selectedRows=[],confirmedMatches={},agency='',savedAgencyAliases=readAgencyAliases();
function aliasKey(name){return String(name??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim().replace(/\s+/g,' ');}
function readAgencyAliases(){
 try{
  const value=JSON.parse(localStorage.getItem(ALIAS_STORAGE)||'{}');
  if(!value||typeof value!=='object'||Array.isArray(value))return {};
  return Object.fromEntries(Object.entries(value).filter(([key,destination])=>
   typeof key==='string'&&key.length>0&&key.length<160&&AGENCES.includes(destination)));
 }catch{return {};}
}
function localSaveAliases(){try{localStorage.setItem(ALIAS_STORAGE,JSON.stringify(savedAgencyAliases));}catch{}}
function resolvedAgency(raw){
 const key=aliasKey(raw);
 // Any explicitly confirmed coordinator association wins, even if the source
 // is itself an official agency name (e.g. AÎT ATTAB -> KHMISS OULED AYAD).
 if(confirmedMatches[raw])return confirmedMatches[raw];
 if(savedAgencyAliases[key])return savedAgencyAliases[key];
 const exact=agencyMatches(raw).exact;
 if(exact)return savedAgencyAliases[aliasKey(exact)]||exact;
 // Reuse an accepted alias only for an extremely close, unambiguous spelling.
 // Ambiguities are listed for manual review instead of guessing the agency.
 const ranked=Object.entries(savedAgencyAliases).map(([alias,destination])=>({
  destination,score:agencySimilarity(raw,alias)
 })).sort((a,b)=>b.score-a.score);
 const top=ranked[0],rival=ranked.find(item=>item.destination!==top?.destination);
 return aliasKey(raw).replace(/\s/g,'').length>=6&&top&&top.score>=0.86&&(!rival||top.score-rival.score>=0.12)?top.destination:'';
}
function singleAgencySuggestion(raw){
 const match=agencyMatches(raw);
 return !match.exact&&match.suggestions.length===1?match.suggestions[0]:'';
}
// Save a single clear suggestion automatically and reuse that association
// across Bouclage AM, the two Notifications and HDG. Explicit mappings win.
function acceptUnambiguousSuggestions(names){
 const rows=[];
 for(const name of names){
  if(resolvedAgency(name))continue;
  const agency=singleAgencySuggestion(name),key=aliasKey(name);
  if(!agency||!key||key.length>150)continue;
  savedAgencyAliases[key]=agency;
  rows.push({alias:key,agency});
 }
 if(rows.length){
  localSaveAliases();
  renderAssociationList();
  if(adminToken())for(let offset=0;offset<rows.length;offset+=100){
   void callAPI('/api/admin/controle/aliases',{
    administrator:true,method:'POST',body:{items:rows.slice(offset,offset+100)}
   }).catch(()=>{ /* Saved locally and synchronized on next login. */ });
  }
 }
 return rows;
}
async function syncAgencyAliases(){
 if(!adminToken())return;
 try{
  const response=await callAPI('/api/admin/controle/aliases',{administrator:true});
  const data=await response.json(),server={};
  for(const row of data.aliases||[]){
   if(typeof row.alias==='string'&&AGENCES.includes(row.agency)){
    const key=aliasKey(row.alias);if(key)server[key]=row.agency;
   }
  }
  // The central database wins when both copies disagree.
  const localOnly=Object.entries(savedAgencyAliases)
   .filter(([key])=>!Object.hasOwn(server,key)).map(([alias,agency])=>({alias,agency}));
  savedAgencyAliases={...savedAgencyAliases,...server};localSaveAliases();
  for(let i=0;i<localOnly.length;i+=100){
   await callAPI('/api/admin/controle/aliases',{
    administrator:true,method:'POST',body:{items:localOnly.slice(i,i+100)}
   });
  }
  if(books.length)evaluateMapping();
  renderAssociationList();
 }catch{
  // Keep browser-local mappings if the backend is not activated yet.
  renderAssociationList();
 }
}
async function rememberAgencyAlias(raw,destination){
 const key=aliasKey(raw),agency=agencyFor(destination);
 if(!key||key.length>150||!agency)throw Error('Saisissez un nom de destination et choisissez une agence officielle.');
 savedAgencyAliases[key]=agency;
 confirmedMatches[raw]=agency;
 localSaveAliases();refreshImportPreview();renderAssociationList();
 if(!adminToken())return false;
 try{
  await callAPI('/api/admin/controle/aliases',{administrator:true,method:'POST',body:{
   items:[{alias:key,agency}]
  }});
  return true;
 }catch{return false;}
}
async function forgetAgencyAlias(raw){
 const key=aliasKey(raw);if(!Object.hasOwn(savedAgencyAliases,key))return true;
 if(!adminToken())throw Error('Connectez-vous avec le compte coordinateur.');
 // Keep the previous association intact if central deletion fails.
 await callAPI('/api/admin/controle/aliases?alias='+encodeURIComponent(key),{
  administrator:true,method:'DELETE'
 });
 delete savedAgencyAliases[key];delete confirmedMatches[raw];localSaveAliases();
 if(books.length)evaluateMapping();renderAssociationList();
 return true;
}
function renderAssociationList(){
 const panel=$('association-list');if(!panel)return;
 const filter=aliasKey($('association-filter').value);
 const entries=Object.entries(savedAgencyAliases)
  .filter(([alias,destination])=>!filter||alias.includes(filter)||aliasKey(destination).includes(filter))
  .sort((a,b)=>a[0].localeCompare(b[0],'fr'));
 const options=$('association-options');
 if(options&&!options.children.length)options.innerHTML=AGENCES.map(name=>'<option value="'+esc(name)+'"></option>').join('');
 panel.innerHTML=entries.length?entries.map(([alias,destination],index)=>
  '<div class="association-row"><strong>'+esc(alias)+'</strong>'+
  '<input type="search" list="association-options" value="'+esc(destination)+'" data-association-target="'+index+'" aria-label="Agence officielle pour '+esc(alias)+'">'+
  '<button type="button" class="button outline" data-association-save="'+index+'">Modifier</button>'+
  '<button type="button" class="button outline" data-association-delete="'+index+'">Supprimer</button></div>'
 ).join(''):'<p class="hint">Aucune association enregistrée pour cette recherche.</p>';
 for(const [index,[alias]] of entries.entries()){
  const save=panel.querySelector('[data-association-save="'+index+'"]');
  const remove=panel.querySelector('[data-association-delete="'+index+'"]');
  save?.addEventListener('click',async()=>{
   const target=panel.querySelector('[data-association-target="'+index+'"]');
   const agency=agencyFor(target?.value);
   if(!agency){message('Choisissez une agence de la liste principale.');return;}
   save.disabled=true;
   try{
    const central=await rememberAgencyAlias(alias,agency);
    if(books.length)evaluateMapping();
    message('Association modifiée : '+alias+' → '+agency+
      (central?' (enregistrée pour les 4 opérations).':' (enregistrée dans ce navigateur ; synchronisation centrale indisponible).'),true);
   }finally{save.disabled=false;}
  });
  remove?.addEventListener('click',async()=>{
   if(!confirm('Supprimer l’association « '+alias+' » ? Les nouveaux imports utiliseront de nouveau les correspondances ordinaires.'))return;
   remove.disabled=true;
   try{
    await forgetAgencyAlias(alias);
    message('Association supprimée : '+alias+'.',true);
   }catch(e){message('Suppression impossible : '+e.message);}
   finally{remove.disabled=false;}
  });
 }
}
$('edit-associations').addEventListener('click',()=>{
 const box=$('association-manager'),show=box.classList.contains('hidden');
 box.classList.toggle('hidden',!show);
 $('edit-associations').setAttribute('aria-expanded',String(show));
 if(show){renderAssociationList();$('association-filter').focus();}
});
$('association-filter').addEventListener('input',renderAssociationList);
$('association-save').addEventListener('click',async()=>{
 const source=$('association-source').value.trim();
 const dest=agencyFor($('association-agency').value);
 if(!source||!dest){message('Indiquez le nom du fichier Excel et sélectionnez une agence officielle.');return;}
 const btn=$('association-save');btn.disabled=true;
 try{
  const central=await rememberAgencyAlias(source,dest);
  if(books.length)evaluateMapping();
  $('association-source').value='';$('association-agency').value='';
  message('Association enregistrée : '+source+' → '+dest+
    (central?' (valable pour les 4 opérations).':' (sur ce navigateur uniquement ; serveur non disponible).'),true);
 }finally{btn.disabled=false;}
});
function message(text,success=false){const el=$('alert');el.classList.remove('hidden','ok');el.textContent=text;if(success)el.classList.add('ok');window.scrollTo({top:0,behavior:'smooth'});}
function clearMessage(){$('alert').classList.add('hidden');}
function participantToken(){return localStorage.getItem('besoin2027-participant-session')||''}
function adminToken(){return sessionStorage.getItem('besoin2027-coordinateur-session')||''}
async function callAPI(path,{method='GET',body,administrator=false}={}){
 const token=administrator?adminToken():participantToken();
 const headers={'Accept':'application/json'};
 if(body!==undefined)headers['Content-Type']='application/json';
 if(token)headers.Authorization='Bearer '+token;
 let r;
 try{r=await fetch(BASE+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),credentials:'omit',mode:'cors',cache:'no-store'});}
 catch{throw Error('Connexion au serveur impossible. Vérifiez votre connexion et la disponibilité du service.');}
 if(!r.ok){
  if(r.status===404&&/^\/api\/(?:admin\/)?controle\//.test(path))throw Error(unavailableNotice);
  const error=await r.json().catch(()=>({}));
  throw Error(error.error||('Erreur du serveur ('+r.status+'). Mise à jour du service peut-être nécessaire.'));
 }
 return r;
}
async function ensureParticipant(){
 const r=await callAPI('/api/controle/session');
 const data=await r.json();
 if(data.participantToken)localStorage.setItem('besoin2027-participant-session',data.participantToken);
}
function agencySelect(select,placeholder='Choisir une agence'){
 const previous=select.value;
 select.innerHTML='<option value="">'+esc(placeholder)+'</option>'+AGENCES.map(a=>'<option value="'+esc(a)+'">'+esc(a)+'</option>').join('');
 if(AGENCES.includes(previous))select.value=previous;
}
function renderAgencyCatalogue(){
 const field=$('agency-list'),info=$('agency-list-info');
 if(info)info.textContent=AGENCES.length+' agences dans la liste principale.';
 if(field)field.innerHTML='<div class="agency-tags">'+AGENCES.map(a=>'<span>'+esc(a)+'</span>').join('')+'</div>';
 for(const id of ['agency','import-agency'])agencySelect($(id));
 const options=$('association-options');if(options)options.replaceChildren();
 renderAssociationList();
 if(books.length)evaluateMapping();
}
async function loadAgencyCatalogue(){
 try{
  const response=await callAPI('/api/controle/agencies'),data=await response.json();
  if(Array.isArray(data.agencies)&&data.agencies.every(name=>typeof name==='string')){
   AGENCES.splice(0,AGENCES.length,...new Set(data.agencies));
   AGENCES.sort((a,b)=>a.localeCompare(b,'fr'));
  }
 }catch{/* Keep existing 49 agencies if newer catalogue API is not available. */}
 renderAgencyCatalogue();
}
async function addAgency(name){
 const clean=String(name??'').replace(/\\s+/g,' ').trim();
 if(clean.length<2||clean.length>100)throw Error('Saisissez le nom exact de la nouvelle agence (2 à 100 caractères).');
 const response=await callAPI('/api/admin/controle/agencies',{administrator:true,method:'POST',body:{name:clean}});
 const data=await response.json();
 if(Array.isArray(data.agencies))AGENCES.splice(0,AGENCES.length,...data.agencies);
 else if(!AGENCES.includes(data.agency))AGENCES.push(data.agency);
 AGENCES.sort((a,b)=>a.localeCompare(b,'fr'));
 renderAgencyCatalogue();
 return data.agency;
}
$('add-agency-form').addEventListener('submit',async e=>{
 e.preventDefault();
 const button=$('add-agency-button');button.disabled=true;
 try{
  const name=await addAgency($('new-agency-name').value);
  $('new-agency-name').value='';
  message('Agence ajoutée à la liste principale : '+name+'.',true);
 }catch(error){message(error.message);}
 finally{button.disabled=false;}
});
function chooseModule(id){
 moduleId=id;clearMessage();
 document.querySelectorAll('.operation').forEach(button=>{const selected=button.dataset.module===id;button.classList.toggle('selected',selected);button.setAttribute('aria-selected',selected?'true':'false')});
 $('agent-module-label').textContent=MODULES[id];
 agentItems=[];filteredItems=[];recordIndex=0;$('agent-content').classList.add('hidden');$('agent-empty').classList.remove('hidden');
 if(admin)void loadSummary();
 else if($('agency').value)void loadAgent();
 if(books.length)showMapping();
}
document.querySelectorAll('[data-module]').forEach(b=>b.addEventListener('click',()=>chooseModule(b.dataset.module)));
agencySelect($('agency'));
agencySelect($('import-agency'));
const isSingleImport=()=>$('import-scope').value==='single';
function toggleImportScope(){
 const single=isSingleImport();
 $('single-agency-field').classList.toggle('hidden',!single);
 $('agency-column-wrap').classList.toggle('hidden',single);
 if(books.length)showMapping();else refreshImportPreview();
}
$('import-scope').addEventListener('change',toggleImportScope);
$('import-agency').addEventListener('change',()=>{if(books.length)evaluateMapping();else refreshImportPreview();});

$('admin-toggle').addEventListener('click',()=>toggleAdmin(true));
$('close-admin').addEventListener('click',()=>toggleAdmin(false));
function toggleAdmin(flag){
 admin=flag;$('admin-panel').classList.toggle('hidden',!flag);$('agent-panel').classList.toggle('hidden',flag);
 $('admin-toggle').textContent=flag?'Contrôle par agence':'Espace coordinateur';
 if(flag&&adminToken()){setAdminConnected(true);void loadSummary();void syncAgencyAliases();void loadAgencyCatalogue();}
}
function setAdminConnected(yes){$('admin-login').classList.toggle('hidden',yes);$('admin-connected').classList.toggle('hidden',!yes);}
$('login-form').addEventListener('submit',async e=>{
 e.preventDefault();clearMessage();
 try{
  const password=$('password').value;
  const r=await callAPI('/api/admin/login',{method:'POST',body:{password}});
  const data=await r.json();
  if(!data.adminToken)throw Error('Le serveur n’a pas fourni de session coordinateur.');
  sessionStorage.setItem('besoin2027-coordinateur-session',data.adminToken);
  $('password').value='';setAdminConnected(true);await loadAgencyCatalogue();await loadSummary();void syncAgencyAliases();message('Connexion coordinateur établie.',true);
 }catch(error){message(error.message);}
});
$('admin-logout').addEventListener('click',()=>{sessionStorage.removeItem('besoin2027-coordinateur-session');setAdminConnected(false);message('Session coordinateur fermée.',true)});
function fmtNumber(v){return Number(v).toLocaleString('fr-FR');}
function counters(items){
 const pending=items.filter(x=>x.status==='EN_ATTENTE').length,ok=items.filter(x=>x.status==='OK').length,
   anomaly=items.filter(x=>x.status==='ANOMALIE').length;
 return {total:items.length,pending,processed:ok+anomaly,ok,anomaly};
}
function progressMarkup(processed,total){
 const percentage=total?Math.round(100*processed/total):0;
 return '<div class="progress-info"><strong>Avancement : '+percentage+' %</strong><span>'+processed+' / '+total+' codes traités</span></div>'+
   '<div class="progress-track" role="progressbar" aria-label="Progression des contrôles" aria-valuemin="0" aria-valuemax="100" aria-valuenow="'+percentage+'">'+
     '<div class="progress-fill" style="width:'+percentage+'%"></div></div>';
}
async function loadAgent(){
 const selectedAgency=$('agency').value,selectedModule=moduleId;
 const agent=$('agent-name').value.trim().replace(/\s+/g,' ');
 if(agent.length<3||agent.length>90){
  if(selectedAgency)message('Saisissez votre nom et prénom (3 à 90 caractères) avant de consulter les CAB.');
  return;
 }
 try{sessionStorage.setItem('controle-agent-name',agent);}catch{}

 agency=selectedAgency;if(!agency){$('agent-content').classList.add('hidden');$('agent-empty').classList.remove('hidden');return;}
 clearMessage();$('load-codes').disabled=true;
 try{
  await ensureParticipant();
  const r=await callAPI('/api/controle/items?module='+encodeURIComponent(selectedModule)+'&agency='+encodeURIComponent(selectedAgency)+'&agent='+encodeURIComponent(agent));
  const d=await r.json();if(moduleId!==selectedModule||$('agency').value!==selectedAgency)return;
  agentItems=(d.items||[]).filter(x=>x.agency===selectedAgency);
  $('agent-empty').classList.add('hidden');$('agent-content').classList.remove('hidden');recordIndex=0;updateList();
 }catch(error){message(error.message)}
 finally{$('load-codes').disabled=false}
}
$('load-codes').addEventListener('click',loadAgent);
$('agency').addEventListener('change',()=>{if($('agent-name').value.trim().length>=3)void loadAgent();else {$('agent-content').classList.add('hidden');$('agent-empty').classList.remove('hidden');}});
$('status-filter').addEventListener('change',()=>{recordIndex=0;updateList()});
$('code-filter').addEventListener('input',()=>{recordIndex=0;updateList()});
function updateList(){
 const c=counters(agentItems);
 $('stats').innerHTML=[
  ['Codes reçus',c.total,''],['Codes traités',c.processed,'processed'],
  ['Codes restants',c.pending,c.pending?'remaining':'completed'],['Anomalies',c.anomaly,'']
 ].map(([label,count,kind])=>'<div class="stat '+kind+'"><strong>'+fmtNumber(count)+'</strong><span>'+label+'</span></div>').join('');
 $('agent-progress').innerHTML=progressMarkup(c.processed,c.total);
 const filter=$('status-filter').value,search=$('code-filter').value.trim().toLowerCase();
 filteredItems=agentItems.filter(x=>(filter==='ALL'||x.status===filter)&&x.barcode.toLowerCase().includes(search));
 if(recordIndex>=filteredItems.length)recordIndex=Math.max(0,filteredItems.length-1);
 $('record-view').classList.toggle('hidden',!filteredItems.length);
 $('no-records').classList.toggle('hidden',!!filteredItems.length);
 if(filteredItems.length)showRecord();
}
function barcodeSvg(code){
 const patterns={
 '0':'nnnwwnwnn','1':'wnnwnnnnw','2':'nnwwnnnnw','3':'wnwwnnnnn','4':'nnnwwnnnw','5':'wnnwwnnnn','6':'nnwwwnnnn','7':'nnnwnnwnw','8':'wnnwnnwnn','9':'nnwwnnwnn',
 A:'wnnnnwnnw',B:'nnwnnwnnw',C:'wnwnnwnnn',D:'nnnnwwnnw',E:'wnnnwwnnn',F:'nnwnwwnnn',G:'nnnnnwwnw',H:'wnnnnwwnn',I:'nnwnnwwnn',J:'nnnnwwwnn',
 K:'wnnnnnnww',L:'nnwnnnnww',M:'wnwnnnnwn',N:'nnnnwnnww',O:'wnnnwnnwn',P:'nnwnwnnwn',Q:'nnnnnnwww',R:'wnnnnnwwn',S:'nnwnnnwwn',T:'nnnnwnwwn',
 U:'wwnnnnnnw',V:'nwwnnnnnw',W:'wwwnnnnnn',X:'nwnnwnnnw',Y:'wwnnwnnnn',Z:'nwwnwnnnn',
 '-':'nwnnnnwnw','.':'wwnnnnwnn',' ':'nwwnnnwnn','$':'nwnwnwnnn','/':'nwnwnnnwn','+':'nwnnnwnwn','%':'nnnwnwnwn','*':'nwnnwnwnn'};
 const upper=String(code).toUpperCase(),svg=$('barcode-svg');
 svg.replaceChildren();$('barcode-unsupported').classList.toggle('hidden',true);
 if(![...upper].every(c=>!!patterns[c])){
  $('barcode-unsupported').classList.remove('hidden');svg.setAttribute('viewBox','0 0 100 100');return;
 }
 let x=12,rects=[];const sequence='*'+upper+'*';
 for(const ch of sequence){const pattern=patterns[ch];for(let i=0;i<pattern.length;i++){const w=pattern[i]==='w'?6:2;if(i%2===0)rects.push([x,w]);x+=w;}x+=2;}
 svg.setAttribute('viewBox',`0 0 ${x+12} 105`);svg.setAttribute('preserveAspectRatio','xMidYMid meet');
 for(const [pos,width] of rects){let node=document.createElementNS('http://www.w3.org/2000/svg','rect');node.setAttribute('x',String(pos));node.setAttribute('y','0');node.setAttribute('height','100');node.setAttribute('width',String(width));node.setAttribute('fill','#111');svg.appendChild(node);}
}
function showRecord(){
 const row=filteredItems[recordIndex];
 $('record-position').textContent='Code '+(recordIndex+1)+' / '+filteredItems.length+' · '+agency;
 $('barcode-text').textContent=row.barcode;barcodeSvg(row.barcode);
 const status=row.status==='OK'?(row.alreadyNotified?'Déjà notifié':'Bouclé'):row.status==='ANOMALIE'?'Anomalie':'À contrôler';
 $('record-status').textContent=status;
 $('record-status').className='status '+(row.status==='OK'?'ok':row.status==='ANOMALIE'?'bad':'');
 $('observation').value=row.observation||'';
 $('anomaly-box').classList.add('hidden');
 $('previous').disabled=recordIndex===0;$('next').disabled=recordIndex>=filteredItems.length-1;
}
$('previous').addEventListener('click',()=>{recordIndex=Math.max(0,recordIndex-1);showRecord()});
$('next').addEventListener('click',()=>{recordIndex=Math.min(filteredItems.length-1,recordIndex+1);showRecord()});
$('show-anomaly').addEventListener('click',()=>{$('anomaly-box').classList.toggle('hidden');$('observation').focus()});
$('mark-ok').addEventListener('click',()=>void saveReview('OK'));
$('save-anomaly').addEventListener('click',()=>void saveReview('ANOMALIE'));
async function saveReview(status){
 const row=filteredItems[recordIndex];if(!row)return;
 const observation=status==='ANOMALIE'?$('observation').value.trim():'';
 if(status==='ANOMALIE'&&!observation){message('L’observation est obligatoire pour signaler une anomalie.');return;}
 const previousIndex=recordIndex+1;const buttons=[$('mark-ok'),$('save-anomaly')];buttons.forEach(b=>b.disabled=true);
 try{
  const r=await callAPI('/api/controle/review',{method:'POST',body:{module:moduleId,agency,id:row.id,status,observation,agent:$('agent-name').value.trim()}});
  const data=await r.json();row.status=data.status;row.observation=data.observation;row.reviewer=data.reviewer;if(data.status==='OK')row.alreadyNotified=false;
  clearMessage();updateList();
  if($('status-filter').value==='ALL'&&previousIndex<filteredItems.length){recordIndex=previousIndex;showRecord();}
 }catch(error){message(error.message)}
 finally{buttons.forEach(b=>b.disabled=false)}
}
function accessDate(value){
 if(!value)return '—';
 const date=new Date(value);
 return Number.isNaN(date.getTime())?'—':new Intl.DateTimeFormat('fr-FR',{
  timeZone:'Africa/Casablanca',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'
 }).format(date);
}
async function loadSummary(){
 if(!adminToken())return;
 try{
  const r=await callAPI('/api/admin/controle/summary?module='+encodeURIComponent(moduleId),{administrator:true});
  const data=await r.json(),groups=new Map();
  for(const name of AGENCES)groups.set(name,{EN_ATTENTE:0,OK:0,ANOMALIE:0});
  for(const row of data.summary||[]){
   if(!groups.has(row.agency))groups.set(row.agency,{EN_ATTENTE:0,OK:0,ANOMALIE:0});
   groups.get(row.agency)[row.status]=row.quantity;
  }
  const visited=new Map((data.accesses||[]).map(row=>[row.agency,row]));
  const neverOpened=AGENCES.filter(name=>!visited.has(name)).length;
  const totals=[...groups.values()].reduce((acc,c)=>{
    acc.pending+=c.EN_ATTENTE;acc.ok+=c.OK;acc.anomaly+=c.ANOMALIE;return acc;
  },{pending:0,ok:0,anomaly:0});
  const processed=totals.ok+totals.anomaly,all=processed+totals.pending;
  $('admin-totals').innerHTML=[
   ['CAB à contrôler',all,''],['Bouclés',totals.ok,'processed'],
   ['Codes restants',totals.pending,totals.pending?'remaining':'completed'],
   ['Anomalies',totals.anomaly,totals.anomaly?'remaining':'']
  ].map(([label,count,kind])=>'<div class="stat '+kind+'"><strong>'+fmtNumber(count)+'</strong><span>'+label+'</span></div>').join('');
  let html='<div class="controle-progress">'+progressMarkup(processed,all)+'</div>';
  html+='<p><strong>'+AGENCES.length+' agences</strong> · '+(AGENCES.length-neverOpened)+' ayant ouvert la liste · '+neverOpened+' sans consultation enregistrée</p>';
  html+='<div class="summary-scroll"><table><thead><tr><th>Agence</th><th>Qui a vu les codes ?</th><th>Dernière consultation</th><th>Ouvertures</th><th>Bouclés</th><th class="remaining-column">Restants</th><th>Anomalies</th><th>Total</th><th>Détails</th></tr></thead><tbody>';
  for(const [name,c] of groups){
   const access=visited.get(name),seen=!!access,remaining=c.EN_ATTENTE;
   html+='<tr><td>'+esc(name)+'</td>'+
     '<td>'+(seen?'<strong>'+esc(access?.lastAgent||'Nom non enregistré')+'</strong>':'<span class="access-label never">Non consultée</span>')+
     (access?.distinctAgents?' <small>('+access.distinctAgents+' agent(s))</small>':'')+'</td>'+
     '<td>'+accessDate(access?.lastAccessAt)+'</td><td>'+(access?.accessCount||0)+'</td>'+
     '<td><strong class="count-processed">'+c.OK+'</strong></td>'+
     '<td><strong class="'+(remaining?'count-remaining':'count-completed')+'">'+remaining+'</strong></td>'+
     '<td><strong class="'+(c.ANOMALIE?'count-remaining':'')+'">'+c.ANOMALIE+'</strong></td>'+
     '<td>'+(c.OK+c.ANOMALIE+remaining)+'</td>'+
     '<td><button type="button" class="button outline agency-details-button" data-agency="'+esc(name)+'">Voir les CAB</button></td></tr>';
  }
  $('admin-summary').innerHTML=html+'</tbody></table></div><p class="hint">L’agent est identifié par le nom qu’il saisit : cette déclaration n’est pas une authentification nominative vérifiée.</p>';
  $('admin-summary').querySelectorAll('button[data-agency]').forEach(btn=>btn.addEventListener('click',()=>void showAgencyDetails(btn.dataset.agency)));
  $('admin-details').replaceChildren();
 }catch(error){message(error.message);}
}
function detailsSection(title,items,kind){
 const total=items.length;
 const color=kind==='EN_ATTENTE'?'count-remaining':kind==='ANOMALIE'?'count-remaining':'count-processed';
 const rows=items.slice(0,500);
 return '<details class="agency-detail-section" open><summary><strong class="'+color+'">'+esc(title)+' : '+total+'</strong></summary>'+
  '<div class="summary-scroll"><table><thead><tr><th>CAB</th><th>Statut</th><th>Observation</th><th>Agent</th><th>Date du contrôle</th></tr></thead><tbody>'+
  rows.map(item=>'<tr><td>'+esc(item.barcode)+'</td><td>'+esc(item.status==='OK'?(item.alreadyNotified?'Déjà notifié':'Bouclé'):item.status==='ANOMALIE'?'Anomalie':'À contrôler')+'</td>'+
   '<td>'+esc(item.observation||'')+'</td><td>'+esc(item.reviewer||'')+'</td><td>'+accessDate(item.reviewedAt)+'</td></tr>').join('')+
  '</tbody></table></div>'+(total>rows.length?'<p class="hint">Affichage limité à 500 CAB de cette catégorie. Le fichier Excel contient la liste complète.</p>':'')+'</details>';
}
async function showAgencyDetails(name){
 const target=$('admin-details');
 target.innerHTML='<p class="hint">Chargement du suivi de '+esc(name)+'…</p>';
 try{
  const module=moduleId;
  const response=await callAPI('/api/admin/controle/details?module='+encodeURIComponent(module)+'&agency='+encodeURIComponent(name),{administrator:true});
  const data=await response.json();
  if(moduleId!==module)return;
  const items=data.codes||[],consultations=data.consultations||[];
  let html='<h3>Suivi détaillé : '+esc(name)+' · '+esc(MODULES[module])+'</h3>';
  html+='<p><strong>'+items.length+' CAB actifs</strong> · '+consultations.length+' consultations récentes (maximum 200 affichées)</p>';
  html+=detailsSection('Bouclés',items.filter(x=>x.status==='OK'),'OK');
  html+=detailsSection('Restants',items.filter(x=>x.status==='EN_ATTENTE'),'EN_ATTENTE');
  html+=detailsSection('Anomalies',items.filter(x=>x.status==='ANOMALIE'),'ANOMALIE');
  html+='<h4>Historique : qui a consulté les CAB ?</h4><div class="summary-scroll"><table><thead><tr><th>Nom déclaré de l’agent</th><th>Date et heure</th><th>CAB visibles</th></tr></thead><tbody>'+
   consultations.map(row=>'<tr><td>'+esc(row.agent)+'</td><td>'+accessDate(row.date)+'</td><td>'+fmtNumber(row.quantity)+'</td></tr>').join('')+'</tbody></table></div>';
  if(!consultations.length)html+='<p class="hint">Aucune consultation nominative enregistrée pour cette opération.</p>';
  if(data.truncated)html+='<p class="hint">Certains CAB dépassent la limite d’affichage. Consultez le fichier Excel.</p>';
  target.innerHTML=html;
  target.scrollIntoView({behavior:'smooth',block:'start'});
 }catch(error){target.textContent='Détails indisponibles : '+error.message;}
}
$('refresh-summary').addEventListener('click',loadSummary);
$('export-button').addEventListener('click',async()=>{
 const button=$('export-button');button.disabled=true;
 try{
  const token=adminToken();
  const r=await fetch(BASE+'/api/admin/controle/export-xlsx',{headers:{Authorization:'Bearer '+token},mode:'cors',credentials:'omit',cache:'no-store'});
  if(!r.ok){const info=await r.json().catch(()=>({}));throw Error(info.error||'Export Excel indisponible.');}
  const url=URL.createObjectURL(await r.blob()),a=document.createElement('a');
  a.href=url;a.download='Suivi_global_CAB.xlsx';a.click();setTimeout(()=>URL.revokeObjectURL(url),30000);
 }catch(error){message(error.message)}
 finally{button.disabled=false;}
});
// Excel and CSV loading: all files are inspected locally before sending confirmed rows to the server.
async function decodeZip(buffer){
 const bytes=new Uint8Array(buffer),v=new DataView(buffer),u16=p=>v.getUint16(p,true),u32=p=>v.getUint32(p,true);
 let eocd=-1;for(let p=bytes.length-22;p>=Math.max(0,bytes.length-65557);p--){if(u32(p)===0x06054b50){eocd=p;break}}
 if(eocd<0)throw Error('Le classeur Excel ne contient pas une archive XLSX valide.');
 let offset=u32(eocd+16);const count=u16(eocd+10),files=new Map(),decoder=new TextDecoder();
 for(let i=0;i<count;i++){
  if(u32(offset)!==0x02014b50)throw Error('Archive Excel invalide.');
  const compression=u16(offset+10),size=u32(offset+20),nameLength=u16(offset+28),extra=u16(offset+30),comment=u16(offset+32),local=u32(offset+42);
  const name=decoder.decode(bytes.subarray(offset+46,offset+46+nameLength));
  const begin=local+30+u16(local+26)+u16(local+28);
  if(name.startsWith('xl/worksheets/')||name==='xl/sharedStrings.xml'||name==='xl/workbook.xml'){
   let content=bytes.slice(begin,begin+size);
   if(compression===8){
    if(typeof DecompressionStream!=='function')throw Error('La lecture des fichiers XLSX compressés exige un navigateur récent. Vous pouvez également importer un CSV.');
    try{const stream=new Blob([content]).stream().pipeThrough(new DecompressionStream('deflate-raw'));content=new Uint8Array(await new Response(stream).arrayBuffer());}
    catch{throw Error('La décompression XLSX n’est pas prise en charge par ce navigateur. Enregistrez la feuille au format CSV.');}
   }else if(compression!==0)throw Error('Format de compression Excel non pris en charge.');
   files.set(name,decoder.decode(content));
  }
  offset+=46+nameLength+extra+comment;
 }
 return files;
}
function parseXlsxXml(content){
 const xml=new DOMParser().parseFromString(content,'application/xml');
 if(xml.querySelector('parsererror'))throw Error('XML Excel invalide.');
 return xml;
}
function textOf(node){return node?.textContent||''}
function csvRows(src){
 const input=src.replace(/^\ufeff/,''),first=input.split(/\r?\n/,1)[0];
 const delim=[';',',','\t'].sort((a,b)=>first.split(b).length-first.split(a).length)[0];
 let rows=[],row=[],field='',quoted=false;
 for(let i=0;i<input.length;i++){
  let c=input[i];
  if(c==='"'){if(quoted&&input[i+1]==='"'){field+='"';i++}else quoted=!quoted}
  else if(c===delim&&!quoted){row.push(field);field=''}
  else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&input[i+1]==='\n')i++;row.push(field);if(row.some(s=>s.trim()))rows.push(row);row=[];field=''}
  else field+=c;
 }
 row.push(field);if(row.some(s=>s.trim()))rows.push(row);
 return rows;
}
function columnNumber(name){let n=0;for(const c of name){n=n*26+c.charCodeAt(0)-64;}return n-1}
async function readBook(file){
 if(/\.csv$/i.test(file.name))return [{name:'CSV',rows:csvRows(await file.text())}];
 if(!/\.xlsx$/i.test(file.name))throw Error('Le fichier doit être au format .xlsx ou .csv. Pour un ancien fichier .xls, enregistrez-le en .xlsx.');
 const files=await decodeZip(await file.arrayBuffer());
 const strings=files.has('xl/sharedStrings.xml')?[...parseXlsxXml(files.get('xl/sharedStrings.xml')).getElementsByTagNameNS('*','si')].map(x=>textOf(x)):[];
 const sheets=[...files.keys()].filter(x=>/^xl\/worksheets\/sheet\d+\.xml$/.test(x)).sort((a,b)=>Number(a.match(/sheet(\d+)/)[1])-Number(b.match(/sheet(\d+)/)[1]));
 if(!sheets.length)throw Error('Aucune feuille trouvée dans le classeur.');
 return sheets.map(path=>{
  const xml=parseXlsxXml(files.get(path)),records=[...xml.getElementsByTagNameNS('*','row')],rows=[];
  for(const entry of records){
   const ri=Number(entry.getAttribute('r')||rows.length+1)-1;
   if(ri>50000)throw Error('Le classeur contient trop de lignes.');
   const cells=[];
   for(const c of entry.getElementsByTagNameNS('*','c')){
    const index=columnNumber((c.getAttribute('r')||'A1').match(/^[A-Z]+/)[0]);
    const value=textOf([...c.children].find(el=>el.localName==='v'||el.localName==='is'));
    cells[index]=c.getAttribute('t')==='s'?(strings[Number(value)]||''):value;
   }
   rows[ri]=cells;
  }
  return {name:path.replace('xl/worksheets/','').replace('.xml',''),rows:rows.map(r=>r||[])};
 });
}
// Detect the operation from the official filename, never silently import into the wrong category.
function moduleFromFilename(filename){
 const normalized=normal(filename.replace(/\.(xlsx|csv)$/i,''));
 if(/\bHDG\b/.test(normalized))return 'hdg';
 if(/\bBOUCLAGE\s*AM\b/.test(normalized))return 'bouclage_am';
 if(/\bNOTIFICATION\b/.test(normalized)&&/\bENREGISTRE(?:S)?\b/.test(normalized))return 'notification_enregistree';
 if(/\bNOTIFICATION\b/.test(normalized)&&/\bRECOMMANDE(?:S)?\b/.test(normalized))return 'notification_recommandee';
 return null;
}
$('excel-file').addEventListener('change',async e=>{
 const file=e.target.files[0];if(!file)return;
 // The coordinator chooses the operation. A filename may corroborate it,
 // but it must never silently switch operations or assign data elsewhere.
 const detected=moduleFromFilename(file.name);
 if(detected && detected!==moduleId){
  e.target.value='';books=[];selectedRows=[];$('mapping').classList.add('hidden');
  message('Ce fichier semble correspondre à « '+MODULES[detected]+
   ' » alors que « '+MODULES[moduleId]+' » est sélectionné. Choisissez la bonne opération avant de continuer.');
  return;
 }
 try{
  books=await readBook(file);
  const list=$('excel-sheet');list.disabled=false;
  list.innerHTML=books.map((sheet,i)=>'<option value="'+i+'">'+esc(sheet.name)+'</option>').join('');
  const match=books.findIndex(sheet=>!!detectSpreadsheetColumns(sheet,true));
  if(match>=0)list.value=String(match);
  confirmedMatches={};showMapping();clearMessage();
 }catch(error){books=[];selectedRows=[];$('mapping').classList.add('hidden');message(error.message);}
});
$('excel-sheet').addEventListener('change',showMapping);
function selectedSheet(){return books[Number($('excel-sheet').value)||0];}

const COUNT_AGENCIES=AGENCES;
const norm = s => String(s??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim().replace(/\s+/g,' ');
const clean = s => norm(s).replace(/^(?:(?:AGENCE|BUREAU|ABB|AP|DESTINATION|AG|ETABLISSEMENT|STE)\s+)+/,'').replace(/\s+(?:AGENCE|ABB)$/,'').trim();
function agencySimilarity(name, candidate) {
 const a=clean(name),b=clean(candidate);
 if(!a||!b)return 0;
 if(a===b)return 1;
 const x=a.replace(/\s/g,''),y=b.replace(/\s/g,'');
 if(x===y)return .99;
 const dp=Array.from({length:y.length+1},(_,i)=>i);
 for(let i=1;i<=x.length;i++){
  let prev=dp[0];dp[0]=i;
  for(let j=1;j<=y.length;j++){
   const old=dp[j];dp[j]=Math.min(dp[j]+1,dp[j-1]+1,prev+(x[i-1]===y[j-1]?0:1));prev=old;
  }
 }
 const distance=dp[y.length],score=1-distance/Math.max(x.length,y.length);
 return Math.max(0,score);
}
function agencyMatches(input) {
 const normalized=clean(input);
 const exact=COUNT_AGENCIES.filter(a=>clean(a)===normalized);
 if(exact.length===1)return {exact:exact[0],suggestions:[exact[0]]};
 const ranked=COUNT_AGENCIES.map(agency=>({agency,score:agencySimilarity(input,agency)})).sort((a,b)=>b.score-a.score);
 const best=ranked[0]?.score||0;
 // Suggestions are never automatically assigned. The coordinator must explicitly confirm.
 return {exact:null,suggestions:best>=0.58?ranked.filter(p=>p.score>=Math.max(0.58,best-0.20)).slice(0,5).map(p=>p.agency):[]};
}

function headerColumnKind(value){
 const key=String(value??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'')
   .toUpperCase().replace(/[^A-Z0-9]/g,'');
 if(key==='CAB'||key==='CODEBARRES'||key==='CODEBARRE')return 'cab';
 // Recognizes NomAgence, Nom agence, NOM_AGENCE and the stray comma/N variant.
 if(/^NOMD?AGENCES?N?$/.test(key))return 'agency';
 return '';
}
function detectSpreadsheetColumns(sheet,requireBoth=false){
 if(!sheet)return null;
 const rows=sheet.rows||[];
 const limit=Math.min(rows.length,50);
 for(let rowIndex=0;rowIndex<limit;rowIndex++){
  const types=(rows[rowIndex]||[]).map(headerColumnKind);
  const cab=types.indexOf('cab'),agency=types.indexOf('agency');
  if(cab>=0&&(agency>=0||(!requireBoth&&isSingleImport())))
   return {headerRow:rowIndex,cab,agency};
 }
 return null;
}
function showMapping(){
 const book=selectedSheet();if(!book)return;
 $('mapping').classList.remove('hidden');
 $('agency-column-wrap').classList.toggle('hidden',isSingleImport());
 const rowSelect=$('header-row');
 const detected=detectSpreadsheetColumns(book,true)||detectSpreadsheetColumns(book,false);
 rowSelect.innerHTML='<option value="-1">Sans ligne d’en-tête</option>'+
   book.rows.slice(0,Math.min(book.rows.length,50)).map((row,i)=>
   '<option value="'+i+'">Ligne '+(i+1)+' : '+esc((row||[]).slice(0,4).join(' | ').slice(0,85))+'</option>').join('');
 rowSelect.value=String(detected?.headerRow??-1);
 updateColumns();
}
$('header-row').addEventListener('change',updateColumns);
$('barcode-column').addEventListener('change',evaluateMapping);
$('agency-column').addEventListener('change',evaluateMapping);
function excelLetter(n){let value='';for(let k=n+1;k>0;k=Math.floor((k-1)/26))value=String.fromCharCode(65+(k-1)%26)+value;return value;}
function updateColumns(){
 const book=selectedSheet();if(!book)return;
 const rowNo=Number($('header-row').value),header=rowNo>=0?book.rows[rowNo]||[]:[];
 const width=Math.min(80,Math.max(2,...book.rows.slice(0,40).map(row=>(row||[]).length)));
 for(const id of ['agency-column','barcode-column']){
  $(id).innerHTML=Array.from({length:width},(_,i)=>'<option value="'+i+'">'+
   excelLetter(i)+' — '+esc(String(header[i]||'Colonne '+(i+1)).slice(0,70))+'</option>').join('');
 }
 const agencyColumn=header.findIndex(value=>headerColumnKind(value)==='agency');
 const cabColumn=header.findIndex(value=>headerColumnKind(value)==='cab');
 $('agency-column').value=String(agencyColumn>=0?agencyColumn:1);
 $('barcode-column').value=String(cabColumn>=0?cabColumn:0);
 const recognized=cabColumn>=0&&(agencyColumn>=0||isSingleImport());
 $('column-controls').classList.toggle('hidden',recognized);
 $('columns-detected').classList.toggle('hidden',!recognized);
 $('columns-detected').textContent=recognized?
  'Colonnes reconnues automatiquement : CAB'+(agencyColumn>=0?' et NomAgence':'')+
  ' (ligne '+(rowNo+1)+'). Aucune sélection manuelle nécessaire.':'';
 evaluateMapping();
}
function evaluateMapping(){
 const sheet=selectedSheet();if(!sheet)return;
 const headerNo=Number($('header-row').value),agencyColumn=Number($('agency-column').value);
 const cabColumn=Number($('barcode-column').value),rawRows=sheet.rows.slice(headerNo+1);
 const single=isSingleImport(),destination=$('import-agency').value;
 const explicitHeader=headerNo>=0?sheet.rows[headerNo]||[]:[];
 const sourceAgencyColumn=explicitHeader.findIndex(value=>headerColumnKind(value)==='agency');
 selectedRows=[];confirmedMatches={};
 const observed=new Set(),rawCounts=new Map();let lastName='',duplicates=0;
 const conflicts=new Set();
 for(const row of rawRows){
  const barcode=String(row?.[cabColumn]??'').trim();
  if(!barcode)continue;
  const cellName=String(row?.[single?sourceAgencyColumn:agencyColumn]??'').trim();
  if(!single&&cellName)lastName=cellName;
  const rawAgency=single?destination||'':lastName||'(Nom agence manquant)';
  const key=normal(rawAgency)+'|'+barcode.toUpperCase();
  if(observed.has(key)){duplicates++;continue;}
  observed.add(key);selectedRows.push({rawAgency,barcode,sourceAgencyName:cellName});
  rawCounts.set(rawAgency,(rawCounts.get(rawAgency)||0)+1);
  // If a single-agency file still contains an explicit Nom agence column,
  // reject known codes belonging to another destination.
  if(single&&sourceAgencyColumn>=0&&cellName&&agencyMatches(cellName).exact&&agencyMatches(cellName).exact!==destination)
   conflicts.add(cellName);
 }
 $('import-preview').dataset.duplicates=String(duplicates);
 $('import-preview').dataset.conflicts=JSON.stringify([...conflicts]);
 if(!single)acceptUnambiguousSuggestions(rawCounts.keys());
 const pending=single?[]:[...rawCounts.keys()].filter(name=>!resolvedAgency(name));
 $('unmatched').classList.toggle('hidden',pending.length===0);
 const optionList=AGENCES.map(agency=>'<option value="'+esc(agency)+'"></option>').join('');
 $('unmatched-fields').innerHTML=pending.map((raw,i)=>{
  const matches=agencyMatches(raw).suggestions;
  const suggestion=matches.length?'<p class="hint">Suggestion : '+matches.map(esc).join(' / ')+'</p>':
    '<p class="hint">Aucune correspondance certaine. Recherchez l’agence par son nom.</p>';
  return '<div class="alias-pair"><label for="match-'+i+'">'+esc(raw)+' ('+rawCounts.get(raw)+' CAB)</label>'+suggestion+
   '<input type="search" id="match-'+i+'" list="agency-options-'+i+'" autocomplete="off" placeholder="Écrire pour rechercher une agence..." data-raw="'+esc(raw)+'" aria-label="Rechercher l’agence correspondant à '+esc(raw)+'">'+
   '<datalist id="agency-options-'+i+'">'+optionList+'</datalist><small class="match-feedback">Non associé : ces CAB seront ignorés.</small>'+
   '<button type="button" class="button outline" data-create-agency="'+i+'">Ajouter cette agence à la liste principale</button></div>';
 }).join('');
 $('unmatched-fields').querySelectorAll('button[data-create-agency]').forEach(button=>{
  button.addEventListener('click',async()=>{
   const name=pending[Number(button.dataset.createAgency)];if(!name)return;
   button.disabled=true;
   try{
    const newName=await addAgency(name);
    message('Agence ajoutée à la liste principale : '+newName+'. Ses CAB seront inclus.',true);
   }catch(error){message(error.message);button.disabled=false;}
  });
 });
 $('unmatched-fields').querySelectorAll('input[data-raw]').forEach(input=>{
  input.addEventListener('input',()=>{
   const matched=agencyFor(input.value);
   const feedback=input.parentElement.querySelector('.match-feedback');
   if(matched){
    void rememberAgencyAlias(input.dataset.raw,matched).then(central=>{
     feedback.textContent='Associé à '+matched+(central?' · association enregistrée pour les 4 opérations.':' · association locale enregistrée, synchronisation centrale indisponible.');
     feedback.classList.add('matched');
    });
   }else{
    feedback.textContent='Choisissez un nom d’agence proposé. Sinon, les CAB non attribués seront ignorés.';
    feedback.classList.remove('matched');
   }
   refreshImportPreview();
  });
 });
 const header=headerNo>=0?sheet.rows[headerNo]||[]:[],width=Math.min(15,Math.max(2,...rawRows.slice(0,8).map(row=>(row||[]).length)));
 $('preview-head').innerHTML='<tr>'+Array.from({length:width},(_,i)=>'<th>'+esc(String(header[i]||'Colonne '+excelLetter(i)))+'</th>').join('')+'</tr>';
 $('preview-body').innerHTML=rawRows.slice(0,8).map(row=>'<tr>'+
  Array.from({length:width},(_,i)=>'<td>'+esc(String(row?.[i]??''))+'</td>').join('')+'</tr>').join('');
 refreshImportPreview();
}
function mappedRows(){
 const single=isSingleImport(),destination=$('import-agency').value;
 return selectedRows.map(row=>({...row,agency:single?destination:
   resolvedAgency(row.rawAgency)}));
}
// Codes from a source name that was manually associated with an agency are
// merged with CAB already addressed to that agency. Count each CAB only once
// for the same agency, including when both spellings appear in the Excel file.
function preparedImportRows(rows=mappedRows()){
 const seen=new Set(),assigned=[];
 for(const row of rows){
  if(!row.agency)continue;
  const key=row.agency+'|'+row.barcode.toUpperCase();
  if(seen.has(key))continue;
  seen.add(key);assigned.push(row);
 }
 return assigned;
}
function refreshImportPreview(){
 const single=isSingleImport(),items=mappedRows(),assigned=preparedImportRows(items);
 const unmapped=new Set(items.filter(row=>!row.agency).map(row=>row.rawAgency));
 const counts=new Map(),sources=new Map();
 for(const row of assigned){
  counts.set(row.agency,(counts.get(row.agency)||0)+1);
  const previous=sources.get(row.agency)||{direct:0,attached:0};
  if(agencyMatches(row.rawAgency).exact===row.agency)previous.direct++;
  else previous.attached++;
  sources.set(row.agency,previous);
 }
 const mergedDuplicates=items.filter(row=>row.agency).length-assigned.length;
 const duplicates=Number($('import-preview').dataset.duplicates||0);
 const currentFile=$('excel-file').files[0];
 const mismatchedFile=currentFile && moduleFromFilename(currentFile.name) &&
   moduleFromFilename(currentFile.name)!==moduleId;
 let conflicts=[];try{conflicts=JSON.parse($('import-preview').dataset.conflicts||'[]');}catch{}
 const dest=$('import-agency').value;
 const associatedSources=single?0:new Set(items.filter(row=>row.agency&&agencyMatches(row.rawAgency).exact!==row.agency).map(row=>row.rawAgency)).size;
 if(single){
  $('import-preview').textContent=items.length+' CAB distincts détectés · Agence : '+(dest||'non sélectionnée')+
  (duplicates?' · '+duplicates+' doublon(s) ignoré(s)':'')+
  (conflicts.length?' · ATTENTION : agences différentes détectées dans le fichier : '+conflicts.join(', '):'')+'.';
 }else{
  $('import-preview').textContent=assigned.length+' CAB affectés aux agences (codes directs + codes rattachés) · '+
   associatedSources+' nom(s) rattaché(s) automatiquement ou par vos associations enregistrées · '+
   unmapped.size+' destination(s) ignorée(s)'+
   (duplicates+mergedDuplicates?' · '+(duplicates+mergedDuplicates)+' doublon(s) éliminé(s)':'')+'.';
 }
 $('import-groups').innerHTML=counts.size?'<strong>Répartition prévue : CAB initiaux et CAB des destinations associées</strong><div class="preview"><table><thead><tr><th>Agence</th><th>CAB directs</th><th>CAB rattachés</th><th>Total à afficher à l’agence</th></tr></thead><tbody>'+
 [...counts].sort((a,b)=>a[0].localeCompare(b[0])).map(([name,n])=>'<tr><td>'+esc(name)+'</td><td>'+sources.get(name).direct+'</td><td>'+sources.get(name).attached+'</td><td><strong>'+n+'</strong></td></tr>').join('')+
 '</tbody></table></div>':'';
 $('import-button').disabled=!controleServiceReady||!assigned.length||assigned.length>10000||conflicts.length>0||!!mismatchedFile;
}
$('import-button').addEventListener('click',async()=>{
 const file=$('excel-file').files[0],allItems=mappedRows(),single=isSingleImport(),destination=$('import-agency').value;
 const items=preparedImportRows(allItems);
 const ignored=allItems.filter(row=>!row.agency).length;
 const mergedDuplicates=allItems.filter(row=>row.agency).length-items.length;
 if(file && moduleFromFilename(file.name) && moduleFromFilename(file.name)!==moduleId){
  message('Le nom du fichier indique une autre opération. Revenez à l’opération correspondant au fichier.');return;
 }
 if(!file||!items.length){message('Sélectionnez un fichier contenant des CAB.');return;}
 if(single&&!destination){message('Sélectionnez l’agence destinataire.');return;}
 if(!items.length){message('Aucun CAB associé à une agence. Effectuez au moins une association.');return;}
 let conflicts=[];try{conflicts=JSON.parse($('import-preview').dataset.conflicts||'[]');}catch{}
 if(conflicts.length){message('Le fichier contient des CAB d’une autre agence : '+conflicts.join(', ')+'.');return;}
 const groups=new Set(items.map(row=>row.agency));
 const question=single?
  'Vous allez remplacer les CAB actifs de '+destination+' uniquement dans « '+MODULES[moduleId]+
   ' » par '+items.length+' code(s). Les autres agences ne seront pas modifiées. Confirmer ?':
  'Vous allez importer '+items.length+' CAB pour '+groups.size+' agence(s) dans « '+MODULES[moduleId]+
   ' ». '+ignored+' CAB non affecté(s) seront ignorés et '+mergedDuplicates+
   ' doublon(s) après rattachement seront éliminés. Les listes précédentes de cette opération seront remplacées. Confirmer ?';
 if(!window.confirm(question))return;
 const button=$('import-button');button.disabled=true;
 try{
  const response=await callAPI('/api/admin/controle/import',{method:'POST',administrator:true,body:{
   module:moduleId,scope:single?'single':'all',agency:single?destination:undefined,fileName:file.name,
   items:items.map(({agency,barcode})=>({agency,barcode}))
  }});
  const result=await response.json();
  $('excel-file').value='';books=[];selectedRows=[];confirmedMatches={};
  $('excel-sheet').innerHTML='<option value="">Sélectionner un fichier</option>';$('excel-sheet').disabled=true;
  $('mapping').classList.add('hidden');
  $('preview-head').replaceChildren();$('preview-body').replaceChildren();
  $('import-preview').textContent='';delete $('import-preview').dataset.duplicates;
  delete $('import-preview').dataset.conflicts;
  $('import-groups').replaceChildren();$('unmatched').classList.add('hidden');$('unmatched-fields').replaceChildren();
  message(single?result.imported+' CAB importés pour '+result.agency+' dans « '+MODULES[moduleId]+
    ' ». Les autres agences ne sont pas modifiées.':
    result.imported+' CAB importés et répartis entre '+result.agencies.length+' agence(s) dans « '+MODULES[moduleId]+' ». '+ignored+' CAB non attribué(s) ignoré(s).',true);
  await loadSummary();
 }catch(error){message(error.message);}
 finally{refreshImportPreview();}
});
try{$('agent-name').value=sessionStorage.getItem('controle-agent-name')||'';}catch{}
toggleAdmin(false);
void loadAgencyCatalogue();
void verifyControleService();
