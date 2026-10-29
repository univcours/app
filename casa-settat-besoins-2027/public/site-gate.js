(function(){
'use strict';
const query=new URLSearchParams(location.search);
const page=query.get('page')||'';
if(page==='gestion-comptage'||page==='gestion'||page==='admin')return;
const api=window.__UNIVCOURS_API_BASE__||'https://besoin2027.hamidtawfiq2.chatgpt.site';
fetch(api+'/api/controle/site-status',{cache:'no-store',credentials:'omit',mode:'cors'})
 .then(response=>response.ok?response.json():null)
 .then(state=>{
  if(!state||state.open!==false)return;
  const overlay=document.createElement('div');
  overlay.setAttribute('role','status');
  overlay.style.cssText='position:fixed;inset:0;background:#f3f6f9;color:#12344a;z-index:2147483647;display:flex;align-items:center;justify-content:center;padding:24px;font:16px Arial,sans-serif;text-align:center';
  const panel=document.createElement('div');panel.style.cssText='background:white;padding:36px 24px;border-radius:16px;box-shadow:0 8px 35px #0002;max-width:520px';
  const heading=document.createElement('h1');heading.textContent='Site temporairement fermé';heading.style.fontSize='24px';
  const p=document.createElement('p');p.textContent='Le coordinateur a temporairement suspendu les accès. Veuillez revenir après la réouverture du service.';
  panel.append(heading,p);overlay.append(panel);
  document.body.append(overlay);
 })
 .catch(()=>{ /* A network error is not evidence of a maintenance closure. */ });
})();
