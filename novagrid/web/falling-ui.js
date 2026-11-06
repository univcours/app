import {FALL_WIDTH,FALL_HEIGHT,FALL_PALETTE,fallingConfig,fallingObjective,makeFallingState,
 tryMoveFalling,tryRotateFalling,stepFalling,hardDropFalling,renderFallCells,shapeFor} from './falling.js';
import {createSwipeTracker} from './swipe.js';

export function createBlockfallUI({onFinish,onExit,getLanguage,onSound,onAdBreak}){
 let game=null,config=null,interval=null,paused=false,reported=false,active=false,gesture=null,earned=0,endless=false;
 const el=document.createElement('section');
 el.id='blockfallOverlay';el.className='blockfall-overlay';el.hidden=true;
 el.innerHTML='<div class="fall-panel" role="dialog" aria-modal="true" aria-labelledby="fallTitle">'+
 '<header class="fall-header"><div><div class="fall-eyebrow">NOVAGRID · BLOCKFALL</div><h2 id="fallTitle"></h2><small id="fallStage"></small></div>'+
 '<div class="fall-header-actions"><button id="fallPause" type="button" aria-label="Pause">Ⅱ</button><button id="fallClose" type="button" aria-label="Back to stages">✕</button></div></header>'+
 '<div class="fall-hud"><div><span id="fallScoreLabel"></span><strong id="fallScore">0</strong></div>'+
 '<div><span id="fallLinesLabel"></span><strong id="fallLines">0</strong></div>'+
 '<div><span id="fallGoalLabel"></span><strong id="fallGoal"></strong></div>'+
 '<div class="fall-next"><span id="fallNextLabel"></span><div id="fallNext"></div></div></div>'+
 '<div class="fall-fever-compact"><span id="fallFeverLabel">FEVER</span><div class="fall-fever-track"><i id="fallFeverFill"></i></div></div>'+
 '<div class="fall-board-holder"><div id="fallBoard" class="fall-board" role="grid" aria-label="10 by 18 falling blocks"></div></div>'+
 
 '<div class="fall-tip" id="fallTip"></div>'+
 '<div class="fall-result" id="fallResult" hidden><div class="fall-result-inner"><strong id="fallResultTitle"></strong><p id="fallResultDetails"></p><button id="fallResultAction" type="button"></button></div></div></div>';
 document.body.append(el);
 const get=id=>el.querySelector('#'+id);
 const labels={
  en:{title:'Blockfall Arena',stage:'Stage',score:'SCORE',lines:'LINES',goal:'GOAL',next:'NEXT',win:'Stage complete!',lose:'Try again!',back:'Back to galaxy',retry:'Retry stage',tip:'Drag sideways to steer · Drag down to descend · Tap to rotate',kinds:{lines:'lines',score:'points',drops:'pieces',combos:'chains'}},
  fr:{title:'Arène des blocs',stage:'Niveau',score:'SCORE',lines:'LIGNES',goal:'OBJECTIF',next:'SUIVANT',win:'Niveau réussi !',lose:'Réessayez !',back:'Retour à la galaxie',retry:'Réessayer',tip:'Glissez à gauche/droite pour bouger · Vers le bas pour descendre · Touchez pour tourner',kinds:{lines:'lignes',score:'points',drops:'pièces',combos:'chaînes'}},
  ar:{title:'ساحة القطع الهابطة',stage:'مرحلة',score:'النقاط',lines:'الصفوف',goal:'الهدف',next:'التالية',win:'كملتي المرحلة!',lose:'عاود المحاولة!',back:'رجوع للمجرات',retry:'إعادة المحاولة',tip:'سحب يمين ويسار للتحريك · سحب لتحت للنزول · ضغطة خفيفة للتدوير',kinds:{lines:'صفوف',score:'نقاط',drops:'قطع',combos:'سلاسل'}}
 };
 const t=()=>labels[getLanguage()]||labels.en;
 function key(){return endless?'nova.blockfall.endless.v1':'nova.blockfall.stage.'+game.stageLevel;}
 function persist(){if(!game)return;try{localStorage.setItem(key(),JSON.stringify(game));}catch{}}
 function clearTimer(){if(interval!==null){clearInterval(interval);interval=null;}}
 function syncTimer(){clearTimer();if(active&&!paused&&!game.over&&!document.hidden)interval=setInterval(()=>perform('tick'),endless?Math.max(175,config.interval-Math.floor(game.drops/16)*27):config.interval);}
 function fitBoard(){
  if(!active)return;
  const rect=get('fallBoard').parentElement.getBoundingClientRect();
  const width=Math.max(1,Math.floor(Math.min(rect.width-3,(rect.height-3)*FALL_WIDTH/FALL_HEIGHT)));
  get('fallBoard').style.width=width+'px';
  get('fallBoard').style.height=Math.floor(width*FALL_HEIGHT/FALL_WIDTH)+'px';
 }
 function drawNext(){
  const pane=get('fallNext');pane.replaceChildren();
  const shape=shapeFor(game.nextType);
  const h=Math.max(...shape.map(p=>p[0]))+1,w=Math.max(...shape.map(p=>p[1]))+1;
  pane.style.gridTemplateColumns='repeat('+w+',9px)';
  pane.style.gridTemplateRows='repeat('+h+',9px)';
  const occupied=new Set(shape.map(([r,c])=>r+','+c));
  for(let r=0;r<h;r++)for(let c=0;c<w;c++){
   const tile=document.createElement('span');tile.className='fall-mini';
   if(!occupied.has(r+','+c))tile.style.opacity='0';else tile.style.background=FALL_PALETTE[game.nextType];
   pane.append(tile);
  }
 }
 function render(){
  if(!game||!active)return;
  const words=t();
  get('fallTitle').textContent='▥ '+words.title;
  el.classList.toggle('fall-endless',endless);
  get('fallStage').textContent=endless?(getLanguage()==='ar'?'∞ لعب مستمر':getLanguage()==='fr'?'∞ Jeu sans fin':'∞ Endless arcade'):(getLanguage()==='ar'?'🎮 وضع أركاد إضافي':getLanguage()==='fr'?'🎮 Mode arcade bonus':'🎮 Bonus Arcade mode');
  for(const [k,v] of [['fallScoreLabel','score'],['fallLinesLabel','lines'],['fallGoalLabel','goal'],['fallNextLabel','next']])
   get(k).textContent=words[v];
  get('fallScore').textContent=game.score.toLocaleString();
  get('fallLines').textContent=game.lines.toLocaleString();
  get('fallGoalLabel').textContent=endless?(getLanguage()==='ar'?'سلسلة': 'COMBO'):words.goal;
  get('fallGoal').textContent=endless?'×'+game.combo:fallingObjective(game,config)+'/'+config.goal+' '+words.kinds[config.kind];
  const fever=Math.min(100,(game.combo*24+game.lines*5)%101);
  get('fallFeverLabel').textContent='⚡ FEVER '+fever+'%';
  get('fallFeverFill').style.width=fever+'%';
  get('fallTip').textContent=paused?(getLanguage()==='ar'?'⏸ اللعب متوقف':getLanguage()==='fr'?'⏸ Jeu en pause':'⏸ Paused'):words.tip;
  get('fallPause').textContent=paused?'▶':'Ⅱ';
  drawNext();
  const board=get('fallBoard'),all=renderFallCells(game);
  if(board.children.length!==FALL_HEIGHT*FALL_WIDTH){
   const frag=document.createDocumentFragment();
   for(let i=0;i<FALL_HEIGHT*FALL_WIDTH;i++){
    const cell=document.createElement('div');cell.className='fall-cell';cell.setAttribute('role','gridcell');frag.append(cell);
   }
   board.replaceChildren(frag);
  }
  let i=0;
  for(const row of all)for(const type of row){
   const cell=board.children[i++];
   cell.className='fall-cell'+(type==='ghost'?' fall-ghost':type?' fall-filled':'');
   cell.style.setProperty('--piece-color',FALL_PALETTE[type]||'transparent');
  }
  if(game.over)showResult();
 }
 function showResult(){
  clearTimer();
  if(!reported){reported=true;persist();earned=Number(onFinish?.(game)||0);}
  const words=t();get('fallResult').hidden=false;
  get('fallResultTitle').textContent=endless?(getLanguage()==='ar'?'نهاية الجولة!':getLanguage()==='fr'?'Fin de partie !':'Run complete!'):(game.won?words.win:words.lose);
  get('fallResultDetails').textContent=words.score+': '+game.score+' · '+words.lines+': '+game.lines+(endless?' · COMBO ×'+game.bestCombo:' · '+words.goal+': '+fallingObjective(game,config)+'/'+config.goal+(game.won?' · ✦ +'+earned+' Nova Points':''));
  get('fallResultAction').textContent=endless?(getLanguage()==='ar'?'العب من جديد':getLanguage()==='fr'?'Rejouer':'Play again'):(game.won?words.back:words.retry);
 }
 function perform(action){
  if(!active||paused||game.over)return;
  const prior=game;
  if(action==='left')game=tryMoveFalling(game,-1);
  else if(action==='right')game=tryMoveFalling(game,1);
  else if(action==='rotate')game=tryRotateFalling(game);
  else if(action==='down')game=stepFalling(game,config,true);
  else if(action==='drop')game=hardDropFalling(game,config);
  else game=stepFalling(game,config);
  if(game!==prior){
   if(game.lastClear>0&&game.drops!==prior.drops)onSound?.('clear');
   else if(game.drops!==prior.drops)onSound?.('place');
   else if(action!=='tick')onSound?.('pick');
   persist();render();
   if(endless&&game.drops!==prior.drops)syncTimer();
   if(game.lastClear>0&&game.drops!==prior.drops){
    const board=get('fallBoard');board.classList.remove('fall-line-burst');
    void board.offsetWidth;board.classList.add('fall-line-burst');
   }
  }
 }
 function pause(){if(!active||game.over)return;paused=!paused;gesture=null;syncTimer();render();}
 function exit(withNavigation=true){
  if(!active)return;
  const level=game.stageLevel;
  persist();active=false;gesture=null;clearTimer();el.hidden=true;get('fallResult').hidden=true;
  if(withNavigation)onExit?.(level);
 }
 function open(level,options={}){
  if(active)exit(false);
  endless=options.endless===true;
  config=endless?{...fallingConfig(level),kind:'score',goal:Number.MAX_SAFE_INTEGER}:fallingConfig(level);
  let saved=null;try{saved=JSON.parse(localStorage.getItem(endless?'nova.blockfall.endless.v1':'nova.blockfall.stage.'+level));}catch{}
  if(saved?.mode==='falling'&&saved.stageLevel===level&&!saved.over&&saved.board?.length===FALL_HEIGHT&&
   saved.board.every(row=>Array.isArray(row)&&row.length===FALL_WIDTH)&&saved.active?.cells?.length===4)game=saved;
  else game=makeFallingState(level);
  active=true;paused=false;reported=false;earned=0;gesture=null;el.hidden=false;get('fallResult').hidden=true;
  render();requestAnimationFrame(fitBoard);syncTimer();
 }
 function reset(){
  if(!game)return;game=makeFallingState(game.stageLevel);reported=false;paused=false;earned=0;gesture=null;get('fallResult').hidden=true;
  persist();render();syncTimer();
 }
 get('fallClose').addEventListener('click',()=>exit());
 get('fallPause').addEventListener('click',pause);
 get('fallResultAction').addEventListener('click',async()=>{
  if(endless){await onAdBreak?.();reset();}
  else if(game.won){await onAdBreak?.();exit();}else reset();
 });
 // Move the live piece while the finger moves, not only on pointer release.
 // Pixel-to-cell thresholds adapt to any phone size and preserve fractional drag.
 const boardNode=get('fallBoard');
 function onSwipeMove(e){
  if(!gesture||gesture.id!==e.pointerId||!active||paused||game.over)return;
  e.preventDefault();
  if(game.drops!==gesture.drops){gesture.locked=true;return;}
  const {horizontal,down}=gesture.tracker.update(e.clientX,e.clientY);
  if(gesture.locked||(!horizontal&&!down))return;
  const before=game;
  let next=game;
  const sign=Math.sign(horizontal);
  for(let i=0;i<Math.abs(horizontal);i++){
   const step=tryMoveFalling(next,sign);
   if(step===next)break;
   next=step;
  }
  for(let i=0;i<down;i++){
   const oldDrops=next.drops;
   next=stepFalling(next,config,true);
   if(next.drops!==oldDrops){gesture.locked=true;break;}
  }
  if(next===before)return;
  game=next;
  persist();
  render();
  if(game.drops!==before.drops)onSound?.(game.lastClear?'clear':'place');
  else if(horizontal&&Date.now()-gesture.lastAudio>110){
   onSound?.('pick');gesture.lastAudio=Date.now();
  }
 }
 boardNode.addEventListener('pointerdown',e=>{
  if(!active||paused||game.over||gesture||e.isPrimary===false||e.button!==0)return;
  e.preventDefault();
  const rect=boardNode.getBoundingClientRect();
  gesture={id:e.pointerId,tracker:createSwipeTracker(e.clientX,e.clientY,
   rect.width/FALL_WIDTH,rect.height/FALL_HEIGHT),drops:game.drops,locked:false,lastAudio:0};
  try{boardNode.setPointerCapture(e.pointerId);}catch{}
 });
 boardNode.addEventListener('pointermove',onSwipeMove);
 boardNode.addEventListener('pointerup',e=>{
  if(!gesture||gesture.id!==e.pointerId)return;
  onSwipeMove(e); // capture the final movement, even when no last move event fired
  const current=gesture;gesture=null;
  if(!current.tracker.moved&&!current.locked&&active&&!paused&&!game.over&&game.drops===current.drops)
   perform('rotate');
 });
 boardNode.addEventListener('pointercancel',e=>{if(gesture?.id===e.pointerId)gesture=null;});
 boardNode.addEventListener('lostpointercapture',e=>{if(gesture?.id===e.pointerId)gesture=null;});
 document.addEventListener('keydown',e=>{
  if(!active||el.hidden)return;
  if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown',' ','Escape','p','P'].includes(e.key)){
   e.preventDefault();e.stopImmediatePropagation();
   const actions={ArrowLeft:'left',ArrowRight:'right',ArrowUp:'rotate',ArrowDown:'down',' ':'drop'};
   if(e.key==='Escape')exit();else if(e.key==='p'||e.key==='P')pause();else perform(actions[e.key]);
  }
 },true);
 document.addEventListener('visibilitychange',()=>{if(!active)return;if(document.hidden){paused=true;gesture=null;clearTimer();}else render();});
 window.addEventListener('resize',()=>{if(active)requestAnimationFrame(fitBoard);});
 document.addEventListener('nova:ads-layout',()=>{if(active)requestAnimationFrame(fitBoard);});
 if('ResizeObserver' in window)new ResizeObserver(()=>{if(active)fitBoard();}).observe(get('fallBoard').parentElement);
 return {open,close:()=>exit(),get visible(){return active&&!el.hidden;},get state(){return game;},render};
}
