import {WORLD_SIZE,TOTAL_WORLDS,TOTAL_STAGES,WORLDS_PER_SECTOR,SECTOR_SIZE,
 WORLD_NAMES,WORLD_SYMBOLS,SECTORS,stageConfig,progressSummary,purchaseStage,isStageUnlocked} from './stages.js';
import {getAdsStatus,tryTestInterstitial} from './ads.js';

export function createGalaxyUI({getProgress,setProgress,getState,onStage,getLanguage,onSound}){
 let world=0,sector=0;
 const dict={
  en:{levels:'Levels',world:'World',points:'Nova Points',map:'Galaxy Map',need:'Complete the previous level',
   poor:'Not enough Nova Points',next:'Unlock',test:'Test interstitial',sections:'GAME WORLDS',free:'Play first stage'},
  fr:{levels:'Niveaux',world:'Monde',points:'Points Nova',map:'Carte galactique',need:'Terminez le niveau précédent',
   poor:'Points Nova insuffisants',next:'Débloquer',test:'Tester la publicité',sections:'UNIVERS DE JEU',free:'Jouer le premier niveau'},
  ar:{levels:'المراحل',world:'العالم',points:'نقاط نوفا',map:'خريطة المجرات',need:'أكمل المرحلة السابقة',
   poor:'نقاط نوفا غير كافية',next:'فتح',test:'تجربة الإعلان',sections:'أقسام اللعب',free:'العب أول مرحلة'}
 };
 const language=()=>dict[getLanguage()]||dict.en;
 const root=document.createElement('div');
 root.id='galaxyOverlay';root.className='galaxy-overlay';root.hidden=true;
 root.innerHTML='<div class="galaxy-panel" role="dialog" aria-modal="true" aria-labelledby="galaxyTitle">'+
 '<div class="galaxy-head"><div><div class="galaxy-kicker">✦ NOVAGRID · 12,000 STAGES</div><h2 id="galaxyTitle"></h2><p id="galaxySubtitle"></p></div><button class="galaxy-close" type="button" aria-label="Close">✕</button></div>'+
 '<div class="galaxy-money"><strong id="galaxyCoins"></strong><span id="galaxyStats"></span></div>'+
 '<div class="galaxy-sectors-label" id="galaxySectorsLabel"></div><div class="galaxy-sectors" id="galaxySectors"></div>'+
 '<div class="galaxy-nav"><button id="galaxyPrevious" type="button">‹</button><span id="galaxyWorld"></span><button id="galaxyNext" type="button">›</button></div>'+
 '<div class="galaxy-scroll"><div class="galaxy-grid" id="galaxyGrid"></div></div>'+
 '<div class="galaxy-diagnostics"><small id="galaxyAds"></small><button id="galaxyTestAd" type="button"></button></div></div>';
 document.body.append(root);
 const at=id=>root.querySelector('#'+id);
 const notify=message=>{
  const toast=document.getElementById('toast');
  if(toast){toast.textContent=message;toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),2200);}
 };
 function close(){root.hidden=true;}
 function renderSectors(){
  const t=language(),p=getProgress(),list=at('galaxySectors');
  at('galaxySectorsLabel').textContent=t.sections;
  const fragment=document.createDocumentFragment();
  for(let i=0;i<SECTORS.length;i++){
   const item=SECTORS[i],start=i*SECTOR_SIZE+1,done=Object.keys(p.completed).filter(k=>Number(k)>=start&&Number(k)<start+SECTOR_SIZE&&p.completed[k]>0).length;
   const b=document.createElement('button');b.type='button';
   b.className='sector-card'+(i===sector?' selected':'');
   b.setAttribute('aria-pressed',String(i===sector));
   const icon=document.createElement('strong');icon.className='sector-icon';icon.textContent=item.icon;
   const name=document.createElement('span');name.className='sector-name';name.textContent=item.name[getLanguage()]||item.name.en;
   const count=document.createElement('small');count.textContent=done+'/'+SECTOR_SIZE;
   b.append(icon,name,count);b.title=item.philosophy[getLanguage()]||item.philosophy.en;
   b.addEventListener('click',()=>{
    onSound?.();sector=i;world=i*WORLDS_PER_SECTOR;
    render(); // browser scroll stays in the map, not the game
    b.scrollIntoView?.({behavior:'smooth',inline:'nearest',block:'nearest'});
   });
   fragment.append(b);
  }
  list.replaceChildren(fragment);
 }
 function render(){
  const p=getProgress(),summary=progressSummary(p),t=language(),chapter=SECTORS[sector];
  at('galaxyTitle').textContent=WORLD_SYMBOLS[world]+' '+WORLD_NAMES[world];
  at('galaxySubtitle').textContent=chapter.name[getLanguage()]||chapter.name.en;
  at('galaxyCoins').textContent='✦ '+p.coins.toLocaleString()+' '+t.points;
  at('galaxyStats').textContent=summary.completed+'/'+TOTAL_STAGES+' ★ '+summary.stars;
  at('galaxyWorld').textContent=t.world+' '+(world-sector*WORLDS_PER_SECTOR+1)+'/'+WORLDS_PER_SECTOR+
    ' · '+(world*WORLD_SIZE+1)+'—'+((world+1)*WORLD_SIZE);
  at('galaxyPrevious').disabled=world===sector*WORLDS_PER_SECTOR;
  at('galaxyNext').disabled=world===(sector+1)*WORLDS_PER_SECTOR-1;
  renderSectors();
  const grid=at('galaxyGrid'),fragment=document.createDocumentFragment();
  for(let j=1;j<=WORLD_SIZE;j++){
   const level=world*WORLD_SIZE+j,stars=p.completed[level]||0,mission=stageConfig(level);
   const available=isStageUnlocked(p,level),buy=level===p.unlockedSectors[sector]+1&&!!p.completed[level-1];
   const b=document.createElement('button');b.type='button';
   b.className='galaxy-node mission-'+mission.kind+' '+(stars?'done':available?'ready':buy?'purchasable':'sealed');
   if(getState()?.mode==='stage'&&getState()?.stageLevel===level)b.classList.add('active');
   const num=document.createElement('strong');num.textContent=available?String(level):buy?'✦':'🔒';
   const subtitle=document.createElement('small');
   subtitle.textContent=stars?'★'.repeat(stars):available?'· · ·':buy?mission.unlockCost+' ✦':'·';
   b.append(num,subtitle);
   const mark=document.createElement('i');mark.className='mission-mark';mark.setAttribute('aria-hidden','true');
   mark.textContent=({score:'✦',rows:'═',columns:'║',squares:'▦',combo:'⟡',
    survival:'∞',clearing:'✧',mastery:'✪',charge:'⚡'})[mission.kind];
   b.append(mark);
   b.title=mission.kind+' · '+mission.goal+(mission.boss?' · BOSS':'');
   b.setAttribute('aria-label',t.levels+' '+level+' '+mission.kind+(buy?' '+t.next+' '+mission.unlockCost:''));
   b.addEventListener('click',()=>{
    onSound?.();
    if(available){close();onStage(level);return;}
    if(!buy){notify(t.need);return;}
    const outcome=purchaseStage(getProgress(),level);
    if(!outcome.ok){notify(outcome.reason==='coins'?t.poor:t.need);return;}
    setProgress(outcome.progress);close();onStage(level);
   });
   fragment.append(b);
  }
  grid.replaceChildren(fragment);
  at('galaxyAds').textContent=getAdsStatus().summary;
  at('galaxyTestAd').textContent=t.test;
  at('galaxyTestAd').hidden=getAdsStatus().live;
 }
 function open(level){
  const base=Number.isInteger(level)?level:getState()?.stageLevel||1;
  world=Math.floor((Math.max(1,Math.min(TOTAL_STAGES,base))-1)/WORLD_SIZE);
  sector=Math.floor(world/WORLDS_PER_SECTOR);
  root.hidden=false;render();
 }
 root.querySelector('.galaxy-close').addEventListener('click',close);
 at('galaxyPrevious').addEventListener('click',()=>{world=Math.max(sector*WORLDS_PER_SECTOR,world-1);render();});
 at('galaxyNext').addEventListener('click',()=>{world=Math.min((sector+1)*WORLDS_PER_SECTOR-1,world+1);render();});
 at('galaxyTestAd').addEventListener('click',async()=>{at('galaxyAds').textContent=await tryTestInterstitial();});
 document.addEventListener('nova:ads-status',()=>{if(!root.hidden)at('galaxyAds').textContent=getAdsStatus().summary;});
 return {open,close,render,get visible(){return !root.hidden;}};
}
