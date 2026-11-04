import {TOTAL_STAGES,SECTORS,stageConfig,progressSummary,isStageUnlocked} from './stages.js';
import {getAdsStatus,tryTestInterstitial} from './ads.js';

export function createGalaxyUI({getProgress,getState,onStage,getLanguage,onSound}){
 const root=document.createElement('div');
 root.id='galaxyOverlay';root.className='galaxy-overlay';root.hidden=true;
 root.innerHTML='<div class="galaxy-panel candy-stage-panel" role="dialog" aria-modal="true" aria-labelledby="galaxyTitle">'+
  '<div class="galaxy-head"><div><div class="galaxy-kicker">🍬 NOVAGRID · CANDY ARCADE</div>'+
  '<h2 id="galaxyTitle"></h2><p id="galaxySubtitle"></p></div>'+
  '<button class="galaxy-close" type="button" aria-label="Close stages">✕</button></div>'+
  '<div class="galaxy-money"><strong id="galaxyCoins"></strong><span id="galaxyStats"></span></div>'+
  '<div class="candy-stage-cards" id="galaxyGrid"></div>'+
  '<p class="candy-stage-note" id="galaxyNote"></p>'+
  '<div class="galaxy-diagnostics" hidden><small id="galaxyAds"></small><button id="galaxyTestAd" type="button">Test AdMob</button></div>'+
  '</div>';
 document.body.append(root);
 const at=id=>root.querySelector('#'+id);
 const words={
  en:{title:'Three epic stages',sub:'Master Candy · Launch Rockets · Defeat the Bomb Boss',
   coins:'Nova Points',done:'finished',play:'PLAY NOW',replay:'REPLAY',locked:'LOCKED',need:'Beat the previous stage to unlock this one',
   goal:'Target score',bonus:'Specials',note:'Only three handcrafted stages. More adventures will come later!'},
  fr:{title:'Trois défis épiques',sub:'Candy · Fusées · Boss des bombes',
   coins:'Points Nova',done:'terminés',play:'JOUER',replay:'REJOUER',locked:'BLOQUÉ',need:'Terminez le niveau précédent pour continuer',
   goal:'Score cible',bonus:'Spécial',note:'Seulement trois niveaux soignés. De nouvelles aventures arriveront !'},
  ar:{title:'3 مراحل أسطورية',sub:'الحلوى · الصواريخ · زعيم القنابل',
   coins:'نقاط نوفا',done:'مكتملة',play:'العب دابا',replay:'عاود اللعب',locked:'مقفولة',need:'خاصك تنجح فالمرحلة اللي قبلها',
   goal:'السكور المطلوب',bonus:'التحدي',note:'غير 3 مراحل مصممة بعناية. مغامرات جديدة غادي تزيد من بعد!'}
 };
 const t=()=>words[getLanguage()]||words.en;
 const toast=msg=>{
  const el=document.getElementById('toast');
  if(el){el.textContent=msg;el.classList.add('show');setTimeout(()=>el.classList.remove('show'),1700);}
 };
 function close(){root.hidden=true;}
 function render(){
  const w=t(),p=getProgress(),progress=progressSummary(p);
  at('galaxyTitle').textContent=w.title;
  at('galaxySubtitle').textContent=w.sub;
  at('galaxyCoins').textContent='✦ '+p.coins.toLocaleString()+' '+w.coins;
  at('galaxyStats').textContent=progress.completed+'/'+TOTAL_STAGES+' '+w.done+' · ★'+progress.stars;
  at('galaxyNote').textContent=w.note;
  const frag=document.createDocumentFragment();
  for(let level=1;level<=TOTAL_STAGES;level++){
   const cfg=stageConfig(level),sector=SECTORS[level-1];
   const available=isStageUnlocked(p,level),stars=p.completed[level]||0;
   const card=document.createElement('button');
   card.type='button';card.className='candy-stage-card stage-'+level+
     (stars?' completed':available?' ready':' locked');
   card.setAttribute('aria-disabled',String(!available));
   card.setAttribute('aria-label',(sector.name[getLanguage()]||sector.name.en)+
     (available?' '+w.goal+' '+cfg.scoreTarget:' '+w.locked));
   const badge=document.createElement('span');badge.className='candy-stage-badge';
   badge.textContent=available?sector.icon:'🔒';
   const head=document.createElement('span');head.className='candy-stage-description';
   const title=document.createElement('strong');title.textContent=level+'. '+(sector.name[getLanguage()]||sector.name.en);
   const mission=document.createElement('small');
   mission.textContent=sector.philosophy[getLanguage()]||sector.philosophy.en;
   const stats=document.createElement('span');stats.className='candy-stage-target';
   stats.textContent=w.goal+': '+cfg.scoreTarget+' · '+w.bonus+': '+cfg.specialTarget;
   head.append(title,mission,stats);
   const status=document.createElement('span');status.className='candy-stage-state';
   status.textContent=available?(stars?'★'.repeat(stars):'▶')+' '+(stars?w.replay:w.play):w.locked;
   card.append(badge,head,status);
   card.addEventListener('click',()=>{
    onSound?.();
    if(!available){toast(w.need);return;}
    close();onStage(level);
   });
   frag.append(card);
  }
  at('galaxyGrid').replaceChildren(frag);
  at('galaxyAds').textContent=getAdsStatus().summary;
 }
 function open(){root.hidden=false;render();}
 root.querySelector('.galaxy-close').addEventListener('click',close);
 at('galaxyTestAd').addEventListener('click',async()=>{at('galaxyAds').textContent=await tryTestInterstitial();});
 document.addEventListener('nova:ads-status',()=>{if(!root.hidden)at('galaxyAds').textContent=getAdsStatus().summary;});
 return {open,close,render,get visible(){return !root.hidden;}};
}
