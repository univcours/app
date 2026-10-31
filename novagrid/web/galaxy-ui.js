import {WORLD_SIZE,TOTAL_WORLDS,TOTAL_STAGES,WORLD_NAMES,WORLD_SYMBOLS,stageConfig,progressSummary,purchaseStage} from './stages.js';
import {getAdsStatus,tryTestInterstitial} from './ads.js';

export function createGalaxyUI({getProgress,setProgress,getState,onStage,getLanguage,onSound}){
 let world=0;
 const dict={
  en:{levels:'Levels',world:'World',points:'Nova Points',map:'Galaxy Map',unlocked:'Unlocked',need:'Complete the previous level',poor:'Not enough Nova Points',next:'Unlock',test:'Test interstitial',completed:'Completed'},
  fr:{levels:'Niveaux',world:'Monde',points:'Points Nova',map:'Carte galactique',unlocked:'Débloqué',need:'Terminez le niveau précédent',poor:'Points Nova insuffisants',next:'Débloquer',test:'Tester la publicité',completed:'Terminés'},
  ar:{levels:'المراحل',world:'العالم',points:'نقاط نوفا',map:'خريطة المجرات',unlocked:'مفتوحة',need:'أكمل المرحلة السابقة أولاً',poor:'نقاط نوفا غير كافية',next:'فتح',test:'تجربة الإعلان',completed:'مكتملة'}
 };
 const language=()=>dict[getLanguage()]||dict.en;
 const root=document.createElement('div');
 root.id='galaxyOverlay';root.className='galaxy-overlay';root.hidden=true;
 root.innerHTML='<div class="galaxy-panel" role="dialog" aria-modal="true" aria-labelledby="galaxyTitle">'+
 '<div class="galaxy-head"><div><div class="galaxy-kicker">✦ NOVAGRID GALAXIES · 2,000</div><h2 id="galaxyTitle"></h2><p id="galaxySubtitle"></p></div><button class="galaxy-close" type="button" aria-label="Close">✕</button></div>'+
 '<div class="galaxy-money"><strong id="galaxyCoins"></strong><span id="galaxyStats"></span></div>'+
 '<div class="galaxy-nav"><button id="galaxyPrevious" type="button">‹</button><span id="galaxyWorld"></span><button id="galaxyNext" type="button">›</button></div>'+
 '<div class="galaxy-scroll"><div class="galaxy-grid" id="galaxyGrid"></div></div>'+
 '<div class="galaxy-diagnostics"><small id="galaxyAds"></small><button id="galaxyTestAd" type="button"></button></div></div>';
 document.body.append(root);
 const at=(id)=>root.querySelector('#'+id);
 const notify=(message)=>{
  const toast=document.getElementById('toast');
  if(toast){toast.textContent=message;toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),2200);}
 };
 function close(){root.hidden=true;}
 function render(){
  const p=getProgress(),summary=progressSummary(p),t=language();
  at('galaxyTitle').textContent=WORLD_SYMBOLS[world]+' '+WORLD_NAMES[world];
  at('galaxySubtitle').textContent=t.world+' '+(world+1)+'/'+TOTAL_WORLDS;
  at('galaxyCoins').textContent='✦ '+p.coins.toLocaleString()+' '+t.points;
  at('galaxyStats').textContent=summary.completed+'/'+TOTAL_STAGES+' ★ '+summary.stars;
  at('galaxyWorld').textContent=(world*WORLD_SIZE+1)+' — '+((world+1)*WORLD_SIZE);
  at('galaxyPrevious').disabled=world===0;
  at('galaxyNext').disabled=world===TOTAL_WORLDS-1;
  const grid=at('galaxyGrid'),fragment=document.createDocumentFragment();
  grid.replaceChildren();
  for(let j=1;j<=WORLD_SIZE;j++){
   const level=world*WORLD_SIZE+j,stars=p.completed[level]||0;
   const available=level<=p.unlocked;
   const buy=level===p.unlocked+1&&!!p.completed[level-1];
   const button=document.createElement('button');
   button.type='button';
   button.className='galaxy-node '+(stars?'done':available?'ready':buy?'purchasable':'sealed');
   if(getState()?.mode==='stage'&&getState()?.stageLevel===level)button.classList.add('active');
   const num=document.createElement('strong');
   num.textContent=available?String(level):buy?'✦':'🔒';
   const subtitle=document.createElement('small');
   subtitle.textContent=stars?'★'.repeat(stars):available?'· · ·':buy?stageConfig(level).unlockCost+' ✦':'·';
   button.append(num,subtitle);
   button.setAttribute('aria-label',t.levels+' '+level+(stars?' ★'.repeat(stars):buy?' '+t.next+' '+stageConfig(level).unlockCost:''));
   button.addEventListener('click',()=>{
    onSound?.();
    if(available){close();onStage(level);return;}
    if(!buy){notify(t.need);return;}
    const outcome=purchaseStage(getProgress(),level);
    if(!outcome.ok){notify(outcome.reason==='coins'?t.poor:t.need);return;}
    setProgress(outcome.progress);
    close();onStage(level);
   });
   fragment.append(button);
  }
  grid.append(fragment);
  at('galaxyAds').textContent=getAdsStatus().summary;
  at('galaxyTestAd').textContent=t.test;
  at('galaxyTestAd').hidden=getAdsStatus().live;
 }
 function open(level){
  const base=Number.isInteger(level)?level:getState()?.stageLevel||getProgress().unlocked;
  world=Math.floor((Math.max(1,Math.min(TOTAL_STAGES,base))-1)/WORLD_SIZE);
  root.hidden=false;render();
 }
 root.querySelector('.galaxy-close').addEventListener('click',close);
 at('galaxyPrevious').addEventListener('click',()=>{world=Math.max(0,world-1);render();});
 at('galaxyNext').addEventListener('click',()=>{world=Math.min(TOTAL_WORLDS-1,world+1);render();});
 at('galaxyTestAd').addEventListener('click',async()=>{at('galaxyAds').textContent=await tryTestInterstitial();});
 document.addEventListener('nova:ads-status',()=>{if(!root.hidden)at('galaxyAds').textContent=getAdsStatus().summary;});
 return {open,close,render,get visible(){return !root.hidden;}};
}
