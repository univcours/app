'use strict';
const AGENCES=["AFOURER","BNI AYAT","AÎT ATTAB","TAOUNZA AP","ARBAA AOUNAT","AZEMMOUR","AZILAL","BEJÂAD","BEN AHMED","BNI KHLOUG","GUISSER","BIR JDID","BOUJNIBA","BOULANOUAR","BZOU","DAR OULED ZIDOUH","DEMNATE","EL BOROUJ","RAS EL AIN","OULED ABBOU","EL GARA","EL KSIBA","AGHBALA","FOUM EL ANSER","TAGHZIRT","FOUM JEMÂA","HAD BRADIA","HAD SOUALEM","SIDI RAHAL PLAGE","SOUALEM TRIFIA","HATTANE","KHMISS OULED AYAD","KHMISS ZMAMRA","MLY ABDELLAH","SIDI BOUZID","OUALIDIA","OUAOUIZAGHT","OULED FREJ","OULED M'BAREK","FOUM OUDI","LÂAYAYTA AP","OULED YAÎCH","SIDI BENNOUR","SIDI HAJJAJ","SIDI JABER","SIDI ISMAIL","SOUK TLAT LOULAD","TNIN GHARBIA","ZAOUIA ECHCHEIKH"];
const MODULES={bouclage_am:'Bouclage AM',notification_enregistree:'Notification des envois enregistrés',notification_recommandee:'Notification des envois recommandés'};
const BASE='https://besoin2027.hamidtawfiq2.chatgpt.site';
const $=id=>document.getElementById(id);
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const normal=s=>String(s??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim();
const agencyFor=value=>{const n=normal(value),simple=n.replace(/^(AGENCE|BUREAU|ABB|AP|DESTINATION) /,'');return AGENCES.find(a=>normal(a)===n)||AGENCES.find(a=>normal(a)===simple)||null};
let moduleId='bouclage_am',agentItems=[],filteredItems=[],recordIndex=0,admin=false,books=[],selectedRows=[],unmatchedMap={},agency='';
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
 return {total:items.length,pending:items.filter(x=>x.status==='EN_ATTENTE').length,ok:items.filter(x=>x.status==='OK').length,anomaly:items.filter(x=>x.status==='ANOMALIE').length};
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
 $('stats').innerHTML=[['Codes reçus',c.total],['À contrôler',c.pending],['Conformes',c.ok],['Anomalies',c.anomaly]].map(([label,count])=>'<div class="stat"><strong>'+fmtNumber(count)+'</strong><span>'+label+'</span></div>').join('');
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
  for(const row of data.summary||[]){if(!groups.has(row.agency))groups.set(row.agency,{EN_ATTENTE:0,OK:0,ANOMALIE:0});groups.get(row.agency)[row.status]=row.quantity;}
  const visited=new Map((data.accesses||[]).map(row=>[row.agency,row]));
  const neverOpened=AGENCES.filter(name=>!visited.has(name)).length;
  let html='<p><strong>'+AGENCES.length+' agences</strong> · '+(AGENCES.length-neverOpened)+' ayant consulté la liste · '+neverOpened+' sans consultation enregistrée</p>';
  html+='<div class="summary-scroll"><table><thead><tr><th>Agence</th><th>Accès</th><th>Dernier accès</th><th>Ouvertures</th><th>À contrôler</th><th>OK</th><th>Anomalies</th><th>Total codes</th></tr></thead><tbody>';
  for(const [name,counts] of groups){
   const access=visited.get(name),consulted=!!access;
   html+='<tr><td>'+esc(name)+'</td><td><span class="access-label '+(consulted?'visited':'never')+'">'+(consulted?'Consultée':'Jamais consultée')+'</span></td>'+
    '<td>'+accessDate(access?.lastAccessAt)+'</td><td>'+(access?.accessCount||0)+'</td><td>'+counts.EN_ATTENTE+'</td><td>'+counts.OK+'</td><td>'+counts.ANOMALIE+'</td><td>'+(counts.EN_ATTENTE+counts.OK+counts.ANOMALIE)+'</td></tr>';
  }
  $('admin-summary').innerHTML=html+'</tbody></table></div><p class="hint">« Consultée » signifie qu’une liste de cette agence a été ouverte pour cette opération. Cela n’identifie pas la personne qui l’a ouverte.</p>';
 }catch(error){message(error.message)}
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
$('excel-file').addEventListener('change',async e=>{
 const file=e.target.files[0];if(!file)return;
 try{
  books=await readBook(file);
  const list=$('excel-sheet');list.disabled=false;list.innerHTML=books.map((s,i)=>'<option value="'+i+'">'+esc(s.name)+'</option>').join('');
  unmatchedMap={};showMapping();clearMessage();
 }catch(error){books=[];$('mapping').classList.add('hidden');message(error.message)}
});
$('excel-sheet').addEventListener('change',()=>{unmatchedMap={};showMapping()});
function selectedSheet(){return books[Number($('excel-sheet').value)||0]}
function showMapping(){
 const book=selectedSheet();if(!book)return;
 $('mapping').classList.remove('hidden');
 const select=$('header-row');select.innerHTML=book.rows.slice(0,Math.min(20,book.rows.length)).map((r,i)=>'<option value="'+i+'">Ligne '+(i+1)+' : '+esc((r||[]).slice(0,3).join(' | ').slice(0,75))+'</option>').join('');
 const guess=book.rows.slice(0,20).findIndex(row=>(row||[]).some(v=>/agence|destination|code.barres|suivi|tracking|objet/i.test(String(v))));
 select.value=String(Math.max(0,guess));
 updateColumns();
}
$('header-row').addEventListener('change',updateColumns);
$('agency-column').addEventListener('change',evaluateMapping);
$('barcode-column').addEventListener('change',evaluateMapping);
function updateColumns(){
 const book=selectedSheet(),r=book?.rows[Number($('header-row').value)]||[];
 const width=Math.min(80,Math.max(2,...book.rows.slice(0,40).map(x=>(x||[]).length)));
 for(const id of ['agency-column','barcode-column']){
  $(id).innerHTML=Array.from({length:width},(_,i)=>'<option value="'+i+'">'+String.fromCharCode(65+(i%26))+' — '+esc(String(r[i]||'Colonne '+(i+1)).slice(0,70))+'</option>').join('');
 }
 const guess=regex=>r.findIndex(x=>regex.test(String(x)));
 const agencyIndex=guess(/agence|destination|bureau|établissement|site/i),barcodeIndex=guess(/code.barres|barcode|numéro.*envoi|n°.*envoi|tracking|objet|identifiant/i);
 $('agency-column').value=String(agencyIndex>=0?agencyIndex:0);
 $('barcode-column').value=String(barcodeIndex>=0?barcodeIndex:Math.min(1,width-1));
 evaluateMapping();
}
function evaluateMapping(){
 const book=selectedSheet();if(!book)return;
 const headerIndex=Number($('header-row').value),a=Number($('agency-column').value),b=Number($('barcode-column').value);
 const rows=book.rows.slice(headerIndex+1);
 const totals=new Map();selectedRows=[];
 let lastAgency='';
 for(const row of rows){
  const raw=String(row?.[a]??'').trim(),barcode=String(row?.[b]??'').trim();
  if(raw)lastAgency=raw;
  if(!barcode)continue;
  if(!lastAgency)lastAgency='(Destination vide)';
  selectedRows.push({rawAgency:lastAgency,barcode});
  totals.set(lastAgency,(totals.get(lastAgency)||0)+1);
 }
 const unrecognized=[...totals.keys()].filter(x=>!agencyFor(x));
 $('unmatched').classList.toggle('hidden',!unrecognized.length);
 $('unmatched-fields').innerHTML=unrecognized.map((name,i)=>'<label>'+esc(name)+' ('+totals.get(name)+' codes)<select data-source="'+esc(name)+'" id="assign-'+i+'"><option value="">Associer à une agence</option>'+AGENCES.map(agency=>'<option value="'+esc(agency)+'" '+(unmatchedMap[name]===agency?'selected':'')+'>'+esc(agency)+'</option>').join('')+'</select></label>').join('');
 $('unmatched-fields').querySelectorAll('select').forEach(select=>select.addEventListener('change',()=>{unmatchedMap[select.dataset.source]=select.value;refreshImportPreview()}));
 const header=(book.rows[headerIndex]||[]),head=$('preview-head'),body=$('preview-body');
 head.innerHTML='<tr>'+header.map((v,i)=>'<th>'+esc(String(v||'Colonne '+(i+1)))+'</th>').join('')+'</tr>';
 body.innerHTML=book.rows.slice(headerIndex+1,headerIndex+9).map(row=>'<tr>'+Array.from({length:header.length},(_,i)=>'<td>'+esc(String(row?.[i]??''))+'</td>').join('')+'</tr>').join('');
 refreshImportPreview();
}
function refreshImportPreview(){
 const mapped=selectedRows.filter(x=>agencyFor(x.rawAgency)||unmatchedMap[x.rawAgency]);
 const n=selectedRows.length;
 $('import-preview').textContent=n+' codes détectés · '+mapped.length+' codes associés à une agence · '+(n-mapped.length)+' à associer.';
 $('import-button').disabled=!n||mapped.length!==n||n>10000;
}
$('import-button').addEventListener('click',async()=>{
 const file=$('excel-file').files[0];if(!file)return;
 const items=selectedRows.map(x=>({agency:agencyFor(x.rawAgency)||unmatchedMap[x.rawAgency],barcode:x.barcode}));
 const btn=$('import-button');btn.disabled=true;
 try{
  const r=await callAPI('/api/admin/controle/import',{method:'POST',administrator:true,body:{module:moduleId,fileName:file.name,items}});
  const data=await r.json();
  // Les fichiers XLSX/CSV ne sont jamais envoyés comme pièces jointes au serveur :
  // seule la liste validée des codes-barres est transmise. Libérer en plus la
  // copie temporaire en mémoire et réinitialiser le contrôle de fichier.
  $('excel-file').value='';
  books=[];selectedRows=[];unmatchedMap={};
  $('excel-sheet').innerHTML='<option value="">Sélectionner un fichier</option>';
  $('excel-sheet').disabled=true;
  $('mapping').classList.add('hidden');
  $('preview-head').replaceChildren();
  $('preview-body').replaceChildren();
  $('import-preview').textContent='';
  $('unmatched-fields').replaceChildren();
  $('unmatched').classList.add('hidden');
  btn.disabled=true;
  message(data.imported+' codes-barres importés dans « '+MODULES[moduleId]+' » pour '+data.agencies.length+' agences. Le fichier a été retiré de la zone d’import et libéré de la mémoire temporaire.',true);
  await loadSummary();
 }catch(error){message(error.message)}
 finally{btn.disabled=false}
});
toggleAdmin(false);
