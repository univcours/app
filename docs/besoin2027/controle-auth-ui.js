/* Agency account login, shared-agency authorization and coordinator controls. */
(function(){
'use strict';
const $=id=>document.getElementById(id);
let account=null,open=true;
const key='controle-agency-session';
const token=()=>sessionStorage.getItem(key)||'';
const userAgencies=()=>account?.agencies||[];
const notice=(s,ok=false)=>{const el=$('alert');el.textContent=s;el.classList.remove('hidden','ok');if(ok)el.classList.add('ok');};
const escape=s=>String(s??'').replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
function restrict(){
 const select=$('agency'),previous=select.value,allowed=userAgencies();
 select.innerHTML='<option value="">Choisir une agence</option>'+allowed.map(a=>'<option value="'+escape(a)+'">'+escape(a)+'</option>').join('');
 if(allowed.includes(previous))select.value=previous;
 else if(allowed.length===1)select.value=allowed[0];
}
function renderPublic(){
 $('agency-login').classList.toggle('hidden',!open||!!account);
 $('agency-login-current').classList.toggle('hidden',!open||!account);
 $('agency-selector').classList.toggle('hidden',!open||!account);
 $('site-closed-message').classList.toggle('hidden',open);
 $('agent-content').classList.add('hidden');
 $('agent-empty').classList.toggle('hidden',!open||!account);
 $('agency-login-label').textContent=account?'Connecté : '+account.username+' · '+account.agencies.length+' agence(s) autorisée(s)':'';
 restrict();
}
function setAccount(username,agencies,sessionToken){
 account={username,agencies:agencies.filter(a=>typeof a==='string')};
 if(sessionToken)sessionStorage.setItem(key,sessionToken);
 renderPublic();
}
function clearAccount(){
 account=null;sessionStorage.removeItem(key);
 renderPublic();
}
async function status(){
 try{
  const r=await callAPI('/api/controle/site-status'),data=await r.json();
  open=data.open===true;renderPublic();
  $('site-state-info').textContent=open?'Site ouvert · accès utilisateur autorisé.':'Site fermé · accès utilisateur suspendu.';
  $('site-close').disabled=!open;$('site-open').disabled=open;
 }catch{
  $('site-state-info').textContent='État du site non disponible : la mise à jour du serveur est nécessaire.';
 }
}
async function init(){
 if(token()){
  try{
   const r=await callAPI('/api/controle/me'),info=await r.json();
   if(!Array.isArray(info.agencies)||!info.agencies.length)throw Error('No assignments');
   setAccount(info.username,info.agencies);
  }catch{clearAccount();}
 }else clearAccount();
 await status();
}
window.__controleAuth={
 token,init,restrict,allows:agency=>open&&!!account&&account.agencies.includes(agency),
 refreshAdmin:async()=>{await Promise.all([loadAccounts(),status()]);}
};
$('agency-login-form').addEventListener('submit',async event=>{
 event.preventDefault();
 const btn=$('agency-login-button');btn.disabled=true;
 try{
  const r=await callAPI('/api/controle/login',{method:'POST',body:{
   username:$('agency-username').value.trim(),password:$('agency-password').value
  }});
  const data=await r.json();
  if(!data.agencyToken||!Array.isArray(data.agencies)||!data.agencies.length)
   throw Error('Le compte ne contient aucune agence autorisée.');
  $('agency-password').value='';
  setAccount(data.username,data.agencies,data.agencyToken);
  $('alert').classList.add('hidden');
 }catch(error){notice(error.message);}
 finally{btn.disabled=false;}
});
$('agency-logout').addEventListener('click',async()=>{
 try{await callAPI('/api/controle/logout',{method:'POST'});}catch{}
 clearAccount();
});
function populateAccountAgencySelect(){
 const list=$('account-agency'),previous=list.value;
 list.innerHTML='<option value="">Choisir une agence</option>'+AGENCES.map(a=>'<option value="'+escape(a)+'">'+escape(a)+'</option>').join('');
 if(AGENCES.includes(previous))list.value=previous;
}
async function loadAccounts(){
 if(!adminToken())return;
 populateAccountAgencySelect();
 const target=$('agency-accounts-list');
 try{
  const r=await callAPI('/api/admin/controle/accounts',{administrator:true}),data=await r.json();
  const users=new Map();
  for(const row of data.accounts||[]){
   if(!users.has(row.username))users.set(row.username,[]);
   users.get(row.username).push(row);
  }
  if(!users.size){target.innerHTML='<p class="hint">Aucun compte créé. Attribuez un identifiant et un mot de passe à une agence.</p>';return;}
  target.innerHTML='<div class="summary-scroll"><table><thead><tr><th>Identifiant</th><th>Agences du compte</th><th>Statut</th><th>Action</th></tr></thead><tbody>'+
   [...users].map(([username,rows])=>rows.map(row=>'<tr><td>'+escape(username)+'</td><td>'+escape(row.agency)+'</td>'+
    '<td>'+(row.active?'Actif':'Suspendu')+'</td><td><button type="button" class="button outline account-edit" data-agency="'+escape(row.agency)+'" data-username="'+escape(username)+'" data-active="'+row.active+'">Modifier</button></td></tr>').join('')).join('')+
   '</tbody></table></div>';
  for(const b of target.querySelectorAll('.account-edit')){
   b.addEventListener('click',()=>{
    $('account-agency').value=b.dataset.agency;
    $('account-username').value=b.dataset.username;
    $('account-active').value=b.dataset.active;
    $('account-password').value='';$('account-rotate').value='false';
    $('account-agency').focus();
   });
  }
 }catch(error){target.textContent='Comptes indisponibles : '+error.message;}
}
$('refresh-accounts').addEventListener('click',()=>void loadAccounts());
$('agency-account-form').addEventListener('submit',async event=>{
 event.preventDefault();
 const btn=$('account-save');btn.disabled=true;
 try{
  const r=await callAPI('/api/admin/controle/accounts',{method:'POST',administrator:true,body:{
   agency:$('account-agency').value,
   username:$('account-username').value.trim(),
   password:$('account-password').value,
   active:$('account-active').value==='true',
   changePassword:$('account-rotate').value==='true'
  }});
  const data=await r.json();
  $('account-password').value='';$('account-rotate').value='false';
  await loadAccounts();
  notice('Accès enregistré : '+data.account.username+' → '+data.account.agency+'.',true);
 }catch(error){notice(error.message);}
 finally{btn.disabled=false;}
});
async function updateOpen(value){
 if(!value&&!confirm('Fermer le site à tous les agents ? Vous pourrez le rouvrir depuis le compte coordinateur.'))return;
 const btn=$(value?'site-open':'site-close');btn.disabled=true;
 try{
  const r=await callAPI('/api/admin/controle/site-status',{method:'POST',administrator:true,body:{open:value}});
  const data=await r.json();open=data.open===true;
  renderPublic();await status();
  notice(open?'Le site est ouvert.':'Le site est fermé aux agents.',true);
 }catch(error){notice(error.message);}
 finally{btn.disabled=false;}
}
$('site-open').addEventListener('click',()=>void updateOpen(true));
$('site-close').addEventListener('click',()=>void updateOpen(false));
})();
