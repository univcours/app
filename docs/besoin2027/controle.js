'use strict';
const AGENCES=["AFOURER","BNI AYAT","AÎT ATTAB","TAOUNZA AP","ARBAA AOUNAT","AZEMMOUR","AZILAL","BEJÂAD","BEN AHMED","BNI KHLOUG","GUISSER","BIR JDID","BOUJNIBA","BOULANOUAR","BZOU","DAR OULED ZIDOUH","DEMNATE","EL BOROUJ","RAS EL AIN","OULED ABBOU","EL GARA","EL KSIBA","AGHBALA","FOUM EL ANSER","TAGHZIRT","FOUM JEMÂA","HAD BRADIA","HAD SOUALEM","SIDI RAHAL PLAGE","SOUALEM TRIFIA","HATTANE","KHMISS OULED AYAD","KHMISS ZMAMRA","MLY ABDELLAH","SIDI BOUZID","OUALIDIA","OUAOUIZAGHT","OULED FREJ","OULED M'BAREK","FOUM OUDI","LÂAYAYTA AP","OULED YAÎCH","SIDI BENNOUR","SIDI HAJJAJ","SIDI JABER","SIDI ISMAIL","SOUK TLAT LOULAD","TNIN GHARBIA","ZAOUIA ECHCHEIKH"];
const MODULES={bouclage_am:'Bouclage AM',notification_enregistree:'Notification des envois enregistrés',notification_recommandee:'Notification des envois recommandés',hdg:'HDG'};
const BASE='https://besoin2027.hamidtawfiq2.chatgpt.site';
const $=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const normal=s=>String(s??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim();
const agencyFor=value=>{const n=normal(value),simple=n.replace(/^(AGENCE|BUREAU|ABB|AP|DESTINATION) /,'');return AGENCES.find(a=>normal(a)===n)||AGENCES.find(a=>normal(a)===simple)||null};
let moduleId='bouclage_am',agentItems=[],filteredItems=[],recordIndex=0,admin=false,books=[],selectedRows=[],confirmedMatches={},agency='';
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
 select.innerHTML='<option value="">'+esc(placeholder)+'</option>'+AGENCES.map(a=>'<option value="'+esc(a)+'">'+esc(a)+'</option>').join('');
}
function chooseModule(id){
 moduleId=id;clearMessage();
 document.querySelectorAll('.operation').forEach(button=>{const selected=button.dataset.module===id;button.classList.toggle('selected',selected);button.setAttribute('aria-selected',selected?'true':'false')});
 $('agent-module-label').textContent=MODULES[id];
 agentItems=[];filteredItems=[];recordIndex=0;$('agent-content').classList.add('hidden');$('agent-empty').classList.remove('hidden');
 if(admin)void loadSummary();
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
$('import-agency').addEventListener('change',refreshImportPreview);

$('admin-toggle').addEventListener('click',()=>toggleAdmin(true));
$('close-admin').addEventListener('click',()=>toggleAdmin(false));
function toggleAdmin(flag){
 admin=flag;$('admin-panel').classList.toggle('hidden',!flag);$('agent-panel').classList.toggle('hidden',flag);
 $('admin-toggle').textContent=flag?'Contrôle par agence':'Espace coordinateur';
 if(flag&&adminToken()){setAdminConnected(true);void loadSummary();}
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
  $('password').value='';setAdminConnected(true);await loadSummary();message('Connexion coordinateur établie.',true);
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
 agency=$('agency').value;if(!agency){message('Veuillez choisir votre agence.');return;}
 clearMessage();$('load-codes').disabled=true;
 try{
  await ensureParticipant();
  const r=await callAPI('/api/controle/items?module='+encodeURIComponent(moduleId)+'&agency='+encodeURIComponent(agency));
  const d=await r.json();agentItems=d.items||[];
  $('agent-empty').classList.add('hidden');$('agent-content').classList.remove('hidden');recordIndex=0;updateList();
 }catch(error){message(error.message)}
 finally{$('load-codes').disabled=false}
}
$('load-codes').addEventListener('click',loadAgent);
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
 const status=row.status==='OK'?'Conforme':row.status==='ANOMALIE'?'Anomalie':'À contrôler';
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
  const r=await callAPI('/api/controle/review',{method:'POST',body:{module:moduleId,agency,id:row.id,status,observation}});
  const data=await r.json();row.status=data.status;row.observation=data.observation;
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
  const total=[...groups.values()].reduce((acc,c)=>{
    acc.pending+=c.EN_ATTENTE;acc.ok+=c.OK;acc.anomaly+=c.ANOMALIE;return acc;
  },{pending:0,ok:0,anomaly:0});
  const processed=total.ok+total.anomaly,all=processed+total.pending;
  $('admin-totals').innerHTML=[
   ['CAB à contrôler',all,''],['Codes traités',processed,'processed'],
   ['Codes restants',total.pending,total.pending?'remaining':'completed'],['Anomalies',total.anomaly,'']
  ].map(([label,count,kind])=>'<div class="stat '+kind+'"><strong>'+fmtNumber(count)+'</strong><span>'+label+'</span></div>').join('');
  let html='<div class="controle-progress">'+progressMarkup(processed,all)+'</div>';
  html+='<p><strong>'+AGENCES.length+' agences</strong> · '+(AGENCES.length-neverOpened)+' ayant consulté la liste · '+neverOpened+' sans consultation enregistrée</p>';
  html+='<div class="summary-scroll"><table><thead><tr><th>Agence</th><th>Accès</th><th>Dernier accès</th><th>Ouvertures</th><th>Codes traités</th><th class="remaining-column">Codes restants</th><th>OK</th><th>Anomalies</th><th>Total codes</th></tr></thead><tbody>';
  for(const [name,c] of groups){
   const access=visited.get(name),consulted=!!access,treated=c.OK+c.ANOMALIE,rest=c.EN_ATTENTE;
   html+='<tr><td>'+esc(name)+'</td><td><span class="access-label '+(consulted?'visited':'never')+'">'+(consulted?'Consultée':'Jamais consultée')+'</span></td>'+
     '<td>'+accessDate(access?.lastAccessAt)+'</td><td>'+(access?.accessCount||0)+'</td>'+
     '<td><strong class="count-processed">'+treated+'</strong></td>'+
     '<td><strong class="'+(rest?'count-remaining':'count-completed')+'">'+rest+'</strong></td>'+
     '<td>'+c.OK+'</td><td>'+c.ANOMALIE+'</td><td>'+(treated+rest)+'</td></tr>';
  }
  $('admin-summary').innerHTML=html+'</tbody></table></div><p class="hint">Codes traités = codes OK + codes avec anomalie. « Consultée » signifie seulement qu’une liste a été ouverte, sans identification nominative de l’agent.</p>';
 }catch(error){message(error.message);}
}
$('refresh-summary').addEventListener('click',loadSummary);
$('export-button').addEventListener('click',async()=>{
 try{
  const token=adminToken();
  const r=await fetch(BASE+'/api/admin/controle/export?module='+encodeURIComponent(moduleId),{headers:{Authorization:'Bearer '+token},mode:'cors',credentials:'omit'});
  if(!r.ok)throw Error('Export indisponible.');
  const url=URL.createObjectURL(await r.blob()),a=document.createElement('a');a.href=url;a.download='controle_'+moduleId+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 }catch(error){message(error.message)}
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

function showMapping(){
 const book=selectedSheet();if(!book)return;
 $('mapping').classList.remove('hidden');
 $('agency-column-wrap').classList.toggle('hidden',isSingleImport());
 const rowSelect=$('header-row');
 rowSelect.innerHTML='<option value="-1">Sans ligne d’en-tête</option>'+
   book.rows.slice(0,Math.min(book.rows.length,20)).map((row,i)=>
   '<option value="'+i+'">Ligne '+(i+1)+' : '+esc((row||[]).slice(0,4).join(' | ').slice(0,85))+'</option>').join('');
 const headerGuess=book.rows.slice(0,20).findIndex(row=>{
  const cells=(row||[]).map(value=>normal(value));
  return isSingleImport()?cells.includes('CAB'):(cells.includes('CAB')&&cells.includes('NOM AGENCE'));
 });
 rowSelect.value=String(headerGuess>=0?headerGuess:-1);
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
 const column=name=>header.findIndex(value=>normal(value)===name);
 const agencyColumn=column('NOM AGENCE'),cabColumn=column('CAB');
 $('agency-column').value=String(agencyColumn>=0?agencyColumn:1);
 $('barcode-column').value=String(cabColumn>=0?cabColumn:0);
 evaluateMapping();
}
function evaluateMapping(){
 const sheet=selectedSheet();if(!sheet)return;
 const headerNo=Number($('header-row').value),agencyColumn=Number($('agency-column').value);
 const cabColumn=Number($('barcode-column').value),rawRows=sheet.rows.slice(headerNo+1);
 const single=isSingleImport(),destination=$('import-agency').value;
 const explicitHeader=headerNo>=0?sheet.rows[headerNo]||[]:[];
 const sourceAgencyColumn=explicitHeader.findIndex(value=>normal(value)==='NOM AGENCE');
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
 const pending=single?[]:[...rawCounts.keys()].filter(name=>!agencyMatches(name).exact);
 $('unmatched').classList.toggle('hidden',pending.length===0);
 $('unmatched-fields').innerHTML=pending.map((name,i)=>{
  const matches=agencyMatches(name).suggestions;
  const suggestion=matches.length?'<p class="hint">Suggestion : '+matches.map(esc).join(' / ')+'</p>':
    '<p class="hint">Agence non reconnue. Choisissez-la manuellement.</p>';
  return '<label>'+esc(name)+' ('+rawCounts.get(name)+' code(s))'+suggestion+
   '<select id="match-'+i+'" data-raw="'+esc(name)+'"><option value="">Confirmer une agence...</option>'+
   AGENCES.map(item=>'<option value="'+esc(item)+'">'+esc(item)+'</option>').join('')+'</select></label>';
 }).join('');
 $('unmatched-fields').querySelectorAll('select').forEach(select=>select.addEventListener('change',()=>{
  confirmedMatches[select.dataset.raw]=select.value;refreshImportPreview();
 }));
 const header=headerNo>=0?sheet.rows[headerNo]||[]:[],width=Math.min(15,Math.max(2,...rawRows.slice(0,8).map(row=>(row||[]).length)));
 $('preview-head').innerHTML='<tr>'+Array.from({length:width},(_,i)=>'<th>'+esc(String(header[i]||'Colonne '+excelLetter(i)))+'</th>').join('')+'</tr>';
 $('preview-body').innerHTML=rawRows.slice(0,8).map(row=>'<tr>'+
  Array.from({length:width},(_,i)=>'<td>'+esc(String(row?.[i]??''))+'</td>').join('')+'</tr>').join('');
 refreshImportPreview();
}
function mappedRows(){
 const single=isSingleImport(),destination=$('import-agency').value;
 return selectedRows.map(row=>({...row,agency:single?destination:
   agencyMatches(row.rawAgency).exact||confirmedMatches[row.rawAgency]||''}));
}
function refreshImportPreview(){
 const single=isSingleImport(),items=mappedRows(),assigned=items.filter(row=>row.agency);
 const unmapped=new Set(items.filter(row=>!row.agency).map(row=>row.rawAgency));
 const counts=new Map();
 for(const row of assigned)counts.set(row.agency,(counts.get(row.agency)||0)+1);
 const duplicates=Number($('import-preview').dataset.duplicates||0);
 let conflicts=[];try{conflicts=JSON.parse($('import-preview').dataset.conflicts||'[]');}catch{}
 const dest=$('import-agency').value;
 if(single){
  $('import-preview').textContent=items.length+' CAB distincts détectés · Agence : '+(dest||'non sélectionnée')+
  (duplicates?' · '+duplicates+' doublon(s) ignoré(s)':'')+
  (conflicts.length?' · ATTENTION : agences différentes détectées dans le fichier : '+conflicts.join(', '):'')+'.';
 }else{
  $('import-preview').textContent=items.length+' CAB distincts détectés · '+assigned.length+
   ' associés à une agence · '+unmapped.size+' nom(s) à confirmer'+
   (duplicates?' · '+duplicates+' doublon(s) ignoré(s)':'')+'.';
 }
 $('import-groups').innerHTML=counts.size?'<strong>Répartition prévue</strong><div class="preview"><table><thead><tr><th>Agence</th><th>Nombre de CAB</th></tr></thead><tbody>'+
 [...counts].sort((a,b)=>a[0].localeCompare(b[0])).map(([name,n])=>'<tr><td>'+esc(name)+'</td><td>'+n+'</td></tr>').join('')+
 '</tbody></table></div>':'';
 $('import-button').disabled=!items.length||items.length>10000||unmapped.size>0||conflicts.length>0;
}
$('import-button').addEventListener('click',async()=>{
 const file=$('excel-file').files[0],items=mappedRows(),single=isSingleImport(),destination=$('import-agency').value;
 if(!file||!items.length){message('Sélectionnez un fichier contenant des CAB.');return;}
 if(single&&!destination){message('Sélectionnez l’agence destinataire.');return;}
 if(items.some(row=>!row.agency)){message('Confirmez tous les noms d’agences avant l’importation.');return;}
 let conflicts=[];try{conflicts=JSON.parse($('import-preview').dataset.conflicts||'[]');}catch{}
 if(conflicts.length){message('Le fichier contient des CAB d’une autre agence : '+conflicts.join(', ')+'.');return;}
 const groups=new Set(items.map(row=>row.agency));
 const question=single?
  'Vous allez remplacer les CAB actifs de '+destination+' uniquement dans « '+MODULES[moduleId]+
   ' » par '+items.length+' code(s). Les autres agences ne seront pas modifiées. Confirmer ?':
  'Vous allez importer '+items.length+' CAB pour '+groups.size+' agence(s) dans « '+MODULES[moduleId]+
   ' ». Les listes précédentes de cette opération seront remplacées. Confirmer ?';
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
    result.imported+' CAB importés et répartis entre '+result.agencies.length+' agence(s) dans « '+MODULES[moduleId]+' ».',true);
  await loadSummary();
 }catch(error){message(error.message);}
 finally{refreshImportPreview();}
});
toggleAdmin(false);
