import {OFFERS} from './economy.js';
/* Compact optional overlays; nothing steals pixels from the game board. */
export function createArcadePanels({getWallet,getStats,getLanguage,onBuy,onReward}){
 let openPanel=null,busy=false;
 const root=document.createElement('section');
 root.id='arcadePanel';root.className='nova-side-overlay';root.hidden=true;
 root.innerHTML='<div class="nova-side-dialog" role="dialog" aria-modal="true" aria-labelledby="novaPanelTitle">'+
 '<header><h2 id="novaPanelTitle"></h2><button type="button" id="novaPanelClose" aria-label="Close">✕</button></header>'+
 '<div id="novaPanelBody"></div><small id="novaPanelFeedback" role="status"></small></div>';
 document.body.append(root);
 const el=id=>root.querySelector('#'+id);
 const words={
 en:{shop:'✦ Nova Shop',stats:'🏆 My Records',coins:'Nova Points',watch:'▶ Watch optional ad · +50 points',ads:'Reward only after the video earns a reward. No payment required.',missing:'Not enough points',earned:'Reward received!',unavailable:'Ad unavailable or reward not earned. Try again later.',purchased:'Added to inventory',games:'Games',best:'Best score',moves:'Best moves',combo:'Best combo',intensity:'Highest intensity',world:'World Top 100 requires online verified leaderboards. No global rank is active.',history:'Personal results',heart:'Heart',shield:'Shield'},
 fr:{shop:'✦ Boutique Nova',stats:'🏆 Mes records',coins:'Points Nova',watch:'▶ Vidéo facultative · +50 points',ads:'La récompense est accordée uniquement après validation de la vidéo.',missing:'Pas assez de points',earned:'Récompense gagnée !',unavailable:'Publicité ou récompense indisponible.',purchased:'Ajouté à l’inventaire',games:'Parties',best:'Meilleur score',moves:'Meilleurs coups',combo:'Combo max',intensity:'Intensité max',world:'Top 100 mondial : classement en ligne vérifié requis. Aucun classement global actif.',history:'Mes résultats',heart:'Cœur',shield:'Bouclier'},
 ar:{shop:'✦ متجر نوفا',stats:'🏆 إحصائياتي',coins:'نقاط نوفا',watch:'▶ فيديو مكافأة اختياري · +50 نقطة',ads:'المكافأة كتزاد غير من بعد تأكيد استحقاق الإعلان. بلا شراء بالفلوس.',missing:'النقاط ما كافياش',earned:'ربحتي المكافأة!',unavailable:'الإعلان ما متاحش أو ما تحققش الاستحقاق.',purchased:'تزاد للمخزون',games:'الجولات',best:'أعلى نتيجة',moves:'أكثر الحركات',combo:'أحسن كومبو',intensity:'أقصى صعوبة',world:'الترتيب العالمي Top 100 خاصو ربط آمن بالسيرفر. ما كاينش ترتيب عالمي مفعل.',history:'نتائجي',heart:'قلب',shield:'درع'}
 };
 const t=()=>words[getLanguage()]||words.en;
 function render(){
  if(!openPanel)return;
  const w=t(),body=el('novaPanelBody');body.replaceChildren();
  el('novaPanelTitle').textContent=openPanel==='shop'?w.shop:w.stats;
  if(openPanel==='shop'){
   const wallet=getWallet();
   const balance=document.createElement('p');balance.className='nova-wallet-line';
   balance.textContent='✦ '+wallet.coins.toLocaleString()+' '+w.coins+'   ❤️ '+wallet.heart+'   🛡️ '+wallet.shield;body.append(balance);
   const offers=document.createElement('div');offers.className='nova-offers';
   for(const offer of OFFERS){
    const button=document.createElement('button');button.type='button';button.className='nova-glass-btn';
    button.textContent=offer.label+' '+w[offer.id]+' · ✦ '+offer.cost;
    button.disabled=wallet.coins<offer.cost||wallet[offer.id]>=99;
    button.addEventListener('click',()=>{const ok=onBuy(offer.id);el('novaPanelFeedback').textContent=ok?w.purchased:w.missing;render();});offers.append(button);
   }
   body.append(offers);
   const ad=document.createElement('button');ad.type='button';ad.className='nova-glass-btn nova-ad-btn';ad.textContent=w.watch;ad.disabled=busy;
   ad.addEventListener('click',async()=>{if(busy)return;busy=true;ad.disabled=true;
    try{const ok=await onReward();el('novaPanelFeedback').textContent=ok?w.earned:w.unavailable;}
    catch{el('novaPanelFeedback').textContent=w.unavailable;}
    finally{busy=false;render();}
   });
   body.append(ad);const note=document.createElement('p');note.className='nova-panel-note';note.textContent=w.ads;body.append(note);
  }else{
   const s=getStats();
   const stats=document.createElement('div');stats.className='nova-records';
   for(const [label,value] of [[w.games,s.games],[w.best,s.highest],[w.moves,s.bestMoves],[w.combo,s.bestCombo],[w.intensity,s.bestIntensity]]){
    const item=document.createElement('div');item.textContent=label+': '+value.toLocaleString();stats.append(item);
   }
   body.append(stats);
   const title=document.createElement('h3');title.textContent=w.history;body.append(title);
   const items=s.history.slice().sort((a,b)=>b.score-a.score).slice(0,7);
   for(let i=0;i<items.length;i++){const line=document.createElement('p');line.className='nova-history-line';line.textContent='#'+(i+1)+' '+items[i].mode+' · '+items[i].score.toLocaleString()+' · '+items[i].date;body.append(line);}
   const note=document.createElement('p');note.className='nova-panel-note';note.textContent='🌍 '+w.world;body.append(note);
  }
 }
 function show(which){openPanel=which;root.hidden=false;el('novaPanelFeedback').textContent='';render();}
 function close(){root.hidden=true;openPanel=null;}
 el('novaPanelClose').addEventListener('click',close);
 root.addEventListener('click',e=>{if(e.target===root)close();});
 document.addEventListener('keydown',e=>{if(!root.hidden&&e.key==='Escape'){e.stopImmediatePropagation();close();}},true);
 return {show,close,refresh(){if(!root.hidden)render();}};
}
