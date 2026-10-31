import {FALL_WIDTH,FALL_HEIGHT,FALL_PALETTE,fallingConfig,fallingObjective,makeFallingState,
 tryMoveFalling,tryRotateFalling,stepFalling,hardDropFalling,renderFallCells,shapeFor} from './falling.js';

export function createBlockfallUI({onFinish,onExit,getLanguage,onSound,onAdBreak}){
 let game=null,config=null,interval=null,paused=false,reported=false,active=false,gesture=null;
 const el=document.createElement('section');
 el.id='blockfallOverlay';el.className='blockfall-overlay';el.hidden=true;
 el.innerHTML='<div class="fall-panel" role="dialog" aria-modal="true" aria-labelledby="fallTitle">'+
 '<header class="fall-header"><div><div class="fall-eyebrow">NOVAGRID · BLOCKFALL</div><h2 id="fallTitle"></h2><small id="fallStage"></small></div>'+
 '<div class="fall-header-actions"><button id="fallPause" type="button" aria-label="Pause">Ⅱ</button><button id="fallClose" type="button" aria-label="Back to stages">✕</button></div></header>'+
 '<div class="fall-hud"><div><span id="fallScoreLabel"></span><strong id="fallScore">0</strong></div>'+
 '<div><span id="fallLinesLabel"></span><strong id="fallLines">0</strong></div>'+
 '<div><span id="fallGoalLabel"></span><strong id="fallGoal"></strong></div>'+
 '<div class="fall-next"><span id="fallNextLabel"></span><div id="fallNext"></div></div></div>'+
 '<div class="fall-board-holder"><div id="fallBoard" class="fall-board" role="grid" aria-label="10 by 18 falling blocks"></div></div>'+
 '<div class="fall-controls">'+
 '<button type="button" data-fall="left" aria-label="Left">◀</button>'+
 '<button type="button" data-fall="rotate" aria-label="Rotate">⟳</button>'+
 '<button type="button" data-fall="right" aria-label="Right">▶</button>'+
 '<button type="button" data-fall="down" aria-label="Down">▼</button>'+
 '<button type="button" data-fall="drop" class="fall-drop" aria-label="Drop">⤓</button></div>'+
 '<div class="fall-tip" id="fallTip"></div>'+
 '<div class="fall-result" id="fallResult" hidden><div class="fall-result-inner"><strong id="fallResultTitle"></strong><p id="fallResultDetails"></p><button id="fallResultAction" type="button"></button></div></div></div>';
 document.body.append(el);
 const get=id=>el.querySelector('#'+id);
 const labels={
  en:{title:'Blockfall Arena',stage:'Stage',score:'SCORE',lines:'LINES',goal:'GOAL',next:'NEXT',win:'Stage complete!',lose:'Try again!',back:'Back to galaxy',retry:'Retry stage',tip:'Tap to rotate · Swipe to move · Swipe down to drop',kinds:{lines:'lines',score:'points',drops:'pieces',combos:'chains'}},
  fr:{title:'Arène des blocs',stage:'Niveau',score:'SCORE',lines:'LIGNES',goal:'OBJECTIF',next:'SUIVANT',win:'Niveau réussi !',lose:'Réessayez !',back:'Retour à la galaxie',retry:'Réessayer',tip:'Touchez pour tourner · Glissez pour déplacer · Glissez vers le bas',kinds:{lines:'lignes',score:'points',drops:'pièces',combos:'chaînes'}},
  ar:{title:'ساحة القطع الهابطة',stage:'مرحلة',score:'النقاط',lines:'الصفوف',goal:'الهدف',next:'التالية',win:'كملتي المرحلة!',lose:'عاود المحاولة!',back:'رجوع للمجرات',retry:'إعادة المحاولة',tip:'ضغط للتدوير · سحب للجوانب · سحب للتحت للإسقاط',kinds:{lines:'صفوف',score:'نقاط',drops:'قطع',combos:'سلاسل'}}
 };
 const t=()=>labels[getLanguage()]||labels.en;
 function key(){return 'nova.blockfall.stage.'+game.stageLevel;}
 function persist(){if(!game)return;try{localStorage.setItem(key(),JSON.stringify(game));}catch{}}
 function clearTimer(){if(interval!==null){clearInterval(interval);interval=null;}}
 function syncTimer(){clearTimer();if(active&&!paused&&!game.over&&!document.hidden)interval=setInterval(()=>perform('tick'),config.interval);}
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
  get('fallStage').textContent=words.stage+' '+game.stageLevel+' / 14000';
  for(const [k,v] of [['fallScoreLabel','score'],['fallLinesLabel','lines'],['fallGoalLabel','goal'],['fallNextLabel','next']])
   get(k).textContent=words[v];
  get('fallScore').textContent=game.score.toLocaleString();
  get('fallLines').textContent=game.lines.toLocaleString();
  get('fallGoal').textContent=fallingObjective(game,config)+'/'+config.goal+' '+words.kinds[config.kind];
  get('fallTip').textContent=words.tip;
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
  if(!reported){reported=true;persist();onFinish?.(game);}
  const words=t();get('fallResult').hidden=false;
  get('fallResultTitle').textContent=game.won?words.win:words.lose;
  get('fallResultDetails').textContent=words.score+': '+game.score+' · '+words.lines+': '+game.lines+' · '+words.goal+': '+fallingObjective(game,config)+'/'+config.goal;
  get('fallResultAction').textContent=game.won?words.back:words.retry;
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
  }
 }
 function pause(){if(!active||game.over)return;paused=!paused;syncTimer();render();}
 function exit(withNavigation=true){
  if(!active)return;
  const level=game.stageLevel;
  persist();active=false;clearTimer();el.hidden=true;get('fallResult').hidden=true;
  if(withNavigation)onExit?.(level);
 }
 function open(level){
  if(active)exit(false);
  config=fallingConfig(level);
  let saved=null;try{saved=JSON.parse(localStorage.getItem('nova.blockfall.stage.'+level));}catch{}
  if(saved?.mode==='falling'&&saved.stageLevel===level&&!saved.over&&saved.board?.length===FALL_HEIGHT&&
   saved.board.every(row=>Array.isArray(row)&&row.length===FALL_WIDTH)&&saved.active?.cells?.length===4)game=saved;
  else game=makeFallingState(level);
  active=true;paused=false;reported=false;el.hidden=false;get('fallResult').hidden=true;
  render();requestAnimationFrame(fitBoard);syncTimer();
 }
 function reset(){
  if(!game)return;game=makeFallingState(game.stageLevel);reported=false;paused=false;get('fallResult').hidden=true;
  persist();render();syncTimer();
 }
 get('fallClose').addEventListener('click',()=>exit());
 get('fallPause').addEventListener('click',pause);
 get('fallResultAction').addEventListener('click',async()=>{
  if(game.won){await onAdBreak?.();exit();}else reset();
 });
 el.querySelectorAll('[data-fall]').forEach(b=>b.addEventListener('click',()=>perform(b.dataset.fall)));
 get('fallBoard').addEventListener('pointerdown',e=>{if(active&&!paused&&!game.over)gesture={x:e.clientX,y:e.clientY,id:e.pointerId};});
 get('fallBoard').addEventListener('pointerup',e=>{
  if(!gesture||gesture.id!==e.pointerId)return;
  const dx=e.clientX-gesture.x,dy=e.clientY-gesture.y;gesture=null;
  if(dy>60)perform('drop');else if(Math.abs(dx)>25)perform(dx>0?'right':'left');else perform('rotate');
 });
 get('fallBoard').addEventListener('pointercancel',()=>{gesture=null;});
 document.addEventListener('keydown',e=>{
  if(!active||el.hidden)return;
  if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown',' ','Escape','p','P'].includes(e.key)){
   e.preventDefault();e.stopImmediatePropagation();
   const actions={ArrowLeft:'left',ArrowRight:'right',ArrowUp:'rotate',ArrowDown:'down',' ':'drop'};
   if(e.key==='Escape')exit();else if(e.key==='p'||e.key==='P')pause();else perform(actions[e.key]);
  }
 },true);
 document.addEventListener('visibilitychange',()=>{if(!active)return;if(document.hidden){paused=true;clearTimer();}else render();});
 window.addEventListener('resize',()=>{if(active)requestAnimationFrame(fitBoard);});
 if('ResizeObserver' in window)new ResizeObserver(()=>{if(active)fitBoard();}).observe(get('fallBoard').parentElement);
 return {open,close:()=>exit(),get visible(){return active&&!el.hidden;},get state(){return game;},render};
}
