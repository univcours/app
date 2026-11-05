import {intensityForMoves,intensityLabel} from './progressive.js';
import {advanceFever} from './fever.js';
import {GLASS_COLS,GLASS_ROWS,makeGlassGame,isGlassBoard,canPlaceGlass,runGlassMove} from './glass-engine.js';
import {initializeAds,gameFinished,maybeShowInterstitialOnReplay} from './ads.js';
import {SIZE,makeGame,runMove,canPlace,hasMove} from './engine.js';
import {shapeDimensions,projectDragPoint,dragLift} from './drag.js';
import {createGameAudio} from './audio.js';
import {arcadeEffect} from './arcade-fx.js';
import {stageConfig,startStage,stageWon,stageFailed,rankStage,awardStage,stageObjectiveText,initialProgress,normalizeProgress,isStageUnlocked,applySectorTurn,TOTAL_STAGES,SECTORS} from './stages.js';
import {createGalaxyUI} from './galaxy-ui.js';
import {calculateBoardSize} from './layout.js';
import {createBlockfallUI} from './falling-ui.js';
const T={
 en:{tagline:'A universe of puzzles',eyebrow:'YOUR DAILY BRAIN BOOST',hero1:'Think sharp.',hero2:'Glow brighter.',subtitle:'Place blocks. Clear lines. Chase your next high score.',classic:'Block Puzzle',stages:'Stages',daily:'Daily challenge',blockfall:'Blockfall',score:'SCORE',best:'BEST',streak:'COMBO',hint:'Select a shape, then tap the grid',selected:'Now tap where the shape should land',invalid:'Not enough space! Try another spot',undo:'Undo once',new:'New game',tipTitle:'Cosmic tip',tip:'Fill a row, column or 3×3 square to clear it.',offline:'Offline & private',playAgain:'Play again',close:'Close',gameOver:'Out of space!',gameOverBody:'Every brilliant run starts with another try.',nice:'Cosmic clear!',dailyDone:'Daily challenge completed',newConfirm:'Start a fresh game? Your current progress will be lost.',share:'NovaGrid score',copy:'Score copied!',undoUsed:'Your one undo has been used',none:'Play a move first',dailyLabel:'Daily · '},
 fr:{tagline:'Un univers de puzzles',eyebrow:'LE DÉFI DE VOTRE CERVEAU',hero1:'Pensez vite.',hero2:'Brillez encore.',subtitle:'Placez des blocs. Effacez des lignes. Battez votre record.',classic:'Puzzle Blocs',stages:'Niveaux',daily:'Défi du jour',blockfall:'Blockfall',score:'SCORE',best:'RECORD',streak:'COMBO',hint:'Choisissez une pièce, puis touchez la grille',selected:'Touchez une case pour placer la pièce',invalid:'Espace insuffisant !',undo:'Annuler une fois',new:'Nouvelle partie',tipTitle:'Astuce cosmique',tip:'Complétez une ligne, colonne ou carré 3×3.',offline:'Hors ligne et privé',playAgain:'Rejouer',close:'Fermer',gameOver:'Plus de place !',gameOverBody:'Chaque superbe partie commence par un nouvel essai.',nice:'Super combo !',dailyDone:'Défi quotidien terminé',newConfirm:'Recommencer ? Votre progression sera perdue.',share:'Score NovaGrid',copy:'Score copié !',undoUsed:'Annulation déjà utilisée',none:'Jouez d’abord',dailyLabel:'Défi · '},
 ar:{tagline:'عالم من الألغاز',eyebrow:'تحديك الذهني اليومي',hero1:'فكّر بذكاء.',hero2:'وتألّق أكثر.',subtitle:'ضع القطع. امسح الصفوف. حطّم رقمك القياسي.',classic:'ألغاز المربعات',stages:'المراحل',daily:'تحدي اليوم',blockfall:'بلوك فول',score:'النقاط',best:'الأفضل',streak:'السلسلة',hint:'اختر قطعة ثم اضغط على الشبكة',selected:'اضغط على مكان وضع القطعة',invalid:'لا توجد مساحة كافية!',undo:'تراجع واحد',new:'لعبة جديدة',tipTitle:'نصيحة ذكية',tip:'أكمل صفاً أو عموداً أو مربعاً 3×3 لمسحه.',offline:'دون إنترنت وخصوصي',playAgain:'العب مجدداً',close:'إغلاق',gameOver:'انتهت المساحة!',gameOverBody:'كل محاولة جديدة فرصة لتحطيم الرقم القياسي.',nice:'ممتاز!',dailyDone:'اكتمل تحدي اليوم',newConfirm:'بدء لعبة جديدة؟ سيضيع تقدمك الحالي.',share:'نقاط NovaGrid',copy:'تم نسخ النقاط!',undoUsed:'استخدمت التراجع',none:'العب أولاً',dailyLabel:'يومي · '}
};
const $=id=>document.getElementById(id);const today=()=>new Date().toLocaleDateString('en-CA',{timeZone:'UTC'});
let lang='en';try{lang=localStorage.getItem('nova.lang')||((navigator.language||'en').slice(0,2));}catch{}if(!T[lang])lang='en';
let state,selected=-1,hover=null,undoSnapshot=null,toastTimer=0,drag=null;
let progress=initialProgress(),galaxy=null,falling=null,lastEarned=0;
try{progress=normalizeProgress(JSON.parse(localStorage.getItem('nova.candy.progress.v1')||'null'));}catch{}
const tr=k=>T[lang][k]||T.en[k]||k;
const storage={get(k){try{return localStorage.getItem(k)}catch{return null}},set(k,v){try{localStorage.setItem(k,v)}catch{}}};
const audio=createGameAudio({effectsEnabled:storage.get('nova.effects')!=='off',musicEnabled:storage.get('nova.music')!=='off'});
let puzzlePaused=false;
function togglePuzzlePause(force){
 puzzlePaused=typeof force==='boolean'?force:!puzzlePaused;
 $('pauseOverlay').hidden=!puzzlePaused;
 $('pauseMain').textContent=puzzlePaused?'▶':'Ⅱ';
 $('pauseMain').setAttribute('aria-label',puzzlePaused?'Resume game':'Pause game');
 if(puzzlePaused)cancelDrag();
}
$('settingsOpen').addEventListener('click',()=>{
 const menu=$('settingsMenu');menu.hidden=!menu.hidden;
 $('settingsOpen').setAttribute('aria-expanded',String(!menu.hidden));
});
$('pauseMain').addEventListener('click',()=>togglePuzzlePause());
$('pauseResume').addEventListener('click',()=>togglePuzzlePause(false));
const sky=document.createElement('div');
sky.className='nova-sky';
sky.setAttribute('aria-hidden','true');
sky.innerHTML='<i class="nova-planet"></i><i class="nova-galaxy"></i><i class="nova-orbit"></i><i class="nova-orbit alt"></i><i class="nova-stars"></i>';
document.body.prepend(sky);
function renderAudioButtons(){
 const fx=$('soundBtn'),music=$('musicBtn');
 fx.textContent=audio.effectsEnabled?'🔊':'🔇';
 music.textContent=audio.musicEnabled?'♫':'♪';
 fx.classList.toggle('muted',!audio.effectsEnabled);
 music.classList.toggle('muted',!audio.musicEnabled);
 const captions={
  en:['Mute sound effects','Enable sound effects','Mute background music','Enable background music'],
  fr:['Couper les effets sonores','Activer les effets sonores','Couper la musique','Activer la musique'],
  ar:['كتم مؤثرات الحركة','تشغيل مؤثرات الحركة','كتم الموسيقى الخلفية','تشغيل الموسيقى الخلفية']
 };
 const [fxMute,fxEnable,musicMute,musicEnable]=captions[lang]||captions.en;
 fx.setAttribute('aria-label',audio.effectsEnabled?fxMute:fxEnable);
 music.setAttribute('aria-label',audio.musicEnabled?musicMute:musicEnable);
 fx.setAttribute('aria-pressed',String(audio.effectsEnabled));
 music.setAttribute('aria-pressed',String(audio.musicEnabled));
 fx.title=fx.getAttribute('aria-label');
 music.title=music.getAttribute('aria-label');
}
function saveProgress(){storage.set('nova.candy.progress.v1',JSON.stringify(progress));}
function readGame(mode){
 if(mode==='classic'){
  try{const old=JSON.parse(storage.get('nova.classic.glass.v1'));
   if(old?.mode==='classic'&&!old.over&&isGlassBoard(old.board)&&old.tray?.length===3)return old;}catch{}
  return makeGlassGame();
 }
 try{const s=JSON.parse(storage.get(`nova.${mode}`));if(s&&s.board?.length===9&&s.tray?.length===3&&s.mode===mode&&(!s.date||mode!=='daily'||s.date===today()))return s;}catch{}return makeGame(mode,today());}
function store(){storage.set(state.mode==='classic'?'nova.classic.glass.v1':state.mode==='stage'?'nova.candy.stage.current':`nova.${state.mode}`,JSON.stringify(state));}
function bestKey(){return state.mode==='stage'?`nova.best.candy.${state.stageLevel}`:`nova.best.${state.mode}`;}
function best(){return Number(storage.get(bestKey())||0);}
function setMode(mode){
 if(!['classic','daily'].includes(mode))return;
 cancelDrag();
 if(mode==='stage'){
  let saved=null;try{saved=JSON.parse(storage.get('nova.candy.stage.current'));}catch{}
  state=saved?.mode==='stage'&&isStageUnlocked(progress,saved.stageLevel)&&saved.board?.length===9&&saved.tray?.length===3&&!saved.over?saved:startStage(progress.unlocked);
 }else state=readGame(mode);
 selected=-1;undoSnapshot=null;audio.setStage(mode==='stage'?state.stageLevel:0);
 document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('active',b.dataset.mode===mode));
 render();
}
function launchStage(level){
 if(!isStageUnlocked(progress,level))return;
 cancelDrag();lastEarned=0;audio.setStage(level);
 if(stageConfig(level).sectorId==='blockfall'){
  storage.set('nova.blockfall.lastLevel',String(level));
  document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('active',b.dataset.mode==='blockfall'));
  falling?.open(level);
  return;
 }
 let saved=null;try{saved=JSON.parse(storage.get('nova.candy.stage.current'));}catch{}
 state=saved?.mode==='stage'&&saved.stageLevel===level&&!saved.over&&saved.board?.length===9&&saved.tray?.length===3?saved:startStage(level);
 selected=-1;undoSnapshot=null;
 document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('active',b.dataset.mode==='stage'));
 render();store();
}
function updateStageHUD(){
 const hud=$('stageHud');
 if(!hud||state?.mode!=='stage'){if(hud)hud.hidden=true;return;}
 hud.hidden=false;
 const cfg=stageConfig(state.stageLevel);
 $('stageTitle').textContent=SECTORS[cfg.sector].icon+' '+state.stageLevel+' · '+(SECTORS[cfg.sector].name[lang]||SECTORS[cfg.sector].name.en)+(cfg.boss?' · 💥 '+state.bossHp+'/'+cfg.bossHp:'');
 $('stageStats').textContent=stageObjectiveText(state,lang);
 $('stageCoins').textContent='✦ '+progress.coins;
 $('stageProgressFill').style.width=Math.min(100,Math.round(state.score/cfg.scoreTarget*100))+'%';
}

function saveBest(){if(state.score>best())storage.set(bestKey(),String(state.score));}
function cellClass(r,c){
 const filled=!!state.board[r][c],candy=(r*7+c*3+(state.stageLevel||0)*2)%6;
 const inRegion=(Math.floor(r/3)+Math.floor(c/3))%2===0;
 let cl=filled?'cell block candy-'+candy:'cell'+(inRegion?' region':'');
 if(selected>=0&&state.tray[selected]&&hover){
  const shape=state.tray[selected];
  if(shape.some(([dr,dc])=>hover[0]+dr===r&&hover[1]+dc===c)){
   const valid=state.mode==='classic'?canPlaceGlass(state.board,shape,hover[0],hover[1]):canPlace(state.board,shape,hover[0],hover[1]);
   cl+=valid?' preview':(filled?' blocked':' invalid');
  }
 }
 return cl;
}
function renderBoard(){const board=$('board');board.textContent='';const frag=document.createDocumentFragment();const rows=state.board.length,cols=state.board[0].length;board.setAttribute('aria-label',`${cols} by ${rows} puzzle board`);for(let r=0;r<rows;r++)for(let c=0;c<cols;c++){const el=document.createElement('button');el.type='button';el.className=cellClass(r,c);el.dataset.r=r;el.dataset.c=c;el.setAttribute('role','gridcell');el.setAttribute('aria-label',`Row ${r+1}, column ${c+1}: ${state.board[r][c]?'filled':'empty'}`);el.addEventListener('click',()=>placeAt(r,c));el.addEventListener('pointerenter',()=>{if(selected>=0){hover=[r,c];updateHighlights();}});frag.append(el);}board.append(frag);}
function updateHighlights(){const cells=$('board').children,rows=state.board.length,cols=state.board[0].length;for(let r=0;r<rows;r++)for(let c=0;c<cols;c++)cells[r*cols+c].className=cellClass(r,c);}
function makePiece(shape){const rows=Math.max(...shape.map(v=>v[0]))+1,cols=Math.max(...shape.map(v=>v[1]))+1;const g=document.createElement('span');g.className='piecegrid';g.style.gridTemplateColumns=`repeat(${cols},var(--micro-size,14px))`;g.style.gridTemplateRows=`repeat(${rows},var(--micro-size,14px))`;const occupied=new Set(shape.map(([r,c])=>`${r},${c}`));for(let r=0;r<rows;r++)for(let c=0;c<cols;c++){const b=document.createElement('span');b.className='micro'+(occupied.has(`${r},${c}`)?' candy-'+((r*7+c*3+(state.stageLevel||0)*2)%6):' blank');g.append(b);}return g;}
function selectPiece(index){
 if(puzzlePaused||!state.tray[index]||state.over)return;
 selected=index;hover=null;
 [...$('pieces').children].forEach((el,i)=>el.classList.toggle('selected',i===index));
 $('message').textContent=tr('selected');
 updateHighlights();
}
function renderPieces(){
 const area=$('pieces');area.textContent='';
 state.tray.forEach((shape,i)=>{
  const el=document.createElement('button');el.type='button';
  el.className='piece'+(selected===i?' selected':'');
  el.disabled=!shape||state.over;
  el.setAttribute('aria-label',`Piece ${i+1}, ${shape?.length??0} blocks`);
  if(shape)el.append(makePiece(shape));
  el.addEventListener('pointerdown',e=>startDrag(e,i));
  el.addEventListener('click',e=>{
   if(e.detail!==0)return; // Keyboard/assistive-technology activation; pointer handled separately.
   audio.unlock();selectPiece(i);audio.effect('pick');
  });
  area.append(el);
 });
}
function dragGhost(shape){
 const {rows,cols}=shapeDimensions(shape),el=document.createElement('div');
 el.className='dragghost';el.setAttribute('aria-hidden','true');
 const occupied=new Set(shape.map(([r,c])=>r+','+c));
 for(let r=0;r<rows;r++)for(let c=0;c<cols;c++){
  const tile=document.createElement('span');
  tile.className='dragcell'+(occupied.has(r+','+c)?'':' empty');
  el.append(tile);
 }
 document.body.append(el);
 return el;
}
function startDrag(e,index){
 if(puzzlePaused||!e.isPrimary || e.button!==0 || drag || state.over || !state.tray[index])return;
 e.preventDefault();
 audio.unlock();
 drag={id:e.pointerId,index,startX:e.clientX,startY:e.clientY,active:false,
  target:null,ghost:null,element:e.currentTarget,lift:0};
 try{e.currentTarget.setPointerCapture(e.pointerId);}catch{}
 window.addEventListener('pointermove',moveDrag);
 window.addEventListener('pointerup',endDrag);
 window.addEventListener('pointercancel',cancelDragEvent);
}
function moveDrag(e){
 if(!drag||e.pointerId!==drag.id)return;
 const d=drag;
 if(!d.active&&Math.hypot(e.clientX-d.startX,e.clientY-d.startY)<9)return;
 if(!d.active){
  d.active=true;selected=d.index;
  d.ghost=dragGhost(state.tray[d.index]);
  $('pieces').classList.add('drag-active');
  d.element.classList.add('selected');
  audio.effect('pick');
 }
 const rect=$('board').getBoundingClientRect();
 const shape=state.tray[d.index],{rows,cols}=shapeDimensions(shape);
 const step=rect.width/state.board[0].length;
 d.lift=dragLift(step);
 d.target=projectDragPoint(e.clientX,e.clientY,rect,shape,d.lift,state.board[0].length,state.board.length);
 hover=d.target?[d.target.row,d.target.col]:null;
 const valid=!!d.target&&(state.mode==='classic'?canPlaceGlass(state.board,shape,d.target.row,d.target.col):canPlace(state.board,shape,d.target.row,d.target.col));
 const size=Math.max(17,step-2);
 d.ghost.style.gridTemplateColumns=`repeat(${cols},${size}px)`;
 d.ghost.style.gridTemplateRows=`repeat(${rows},${size}px)`;
 d.ghost.style.left=e.clientX+'px';
 d.ghost.style.top=e.clientY-d.lift+'px';
 d.ghost.classList.toggle('valid',valid);
 d.ghost.classList.toggle('invalid',!valid);
 updateHighlights();
}
function clearDrag(){
 if(!drag)return null;
 const d=drag;drag=null;
 window.removeEventListener('pointermove',moveDrag);
 window.removeEventListener('pointerup',endDrag);
 window.removeEventListener('pointercancel',cancelDragEvent);
 try{if(d.element.hasPointerCapture?.(d.id))d.element.releasePointerCapture(d.id);}catch{}
 d.ghost?.remove();$('pieces').classList.remove('drag-active');
 return d;
}
function endDrag(e){
 if(!drag||e.pointerId!==drag.id)return;
 e.preventDefault();
 // Calculate final position even if the finger was released between move events.
 if(drag.active)moveDrag(e);
 const d=clearDrag();
 if(d.active&&d.target&&(state.mode==='classic'?canPlaceGlass(state.board,state.tray[d.index],d.target.row,d.target.col):canPlace(state.board,state.tray[d.index],d.target.row,d.target.col))){
  selected=d.index;hover=null;placeAt(d.target.row,d.target.col);
 }else{
  selectPiece(d.index);
  if(!d.active)audio.effect('pick');
  else if(d.target){audio.effect('invalid');notify(tr('invalid'));}
 }
}
function cancelDragEvent(e){if(drag?.id===e.pointerId)cancelDrag();}
function cancelDrag(){
 const d=clearDrag();
 if(d){hover=null;if(state)updateHighlights();}
}
function render(){document.documentElement.dataset.grid=state.mode==='classic'?'portrait':'square';document.documentElement.dataset.sector=state.mode==='stage'?stageConfig(state.stageLevel).sectorId:'classic';document.documentElement.lang=lang;document.documentElement.dir=lang==='ar'?'rtl':'ltr';const intensity=intensityForMoves(state.moves||0);const chip=$('intensityChip');if(chip){chip.textContent='⚡ '+intensity+'/9';chip.title=intensityLabel(intensity,lang);chip.setAttribute('aria-label',chip.title);}document.querySelectorAll('[data-i18n]').forEach(el=>{el.textContent=tr(el.dataset.i18n)});$('languageBtn').textContent=lang.toUpperCase()+'⌄';$('score').textContent=state.score.toLocaleString();$('best').textContent=Math.max(best(),state.score).toLocaleString();$('combo').textContent='×'+state.combo;$('undoBtn').disabled=state.usedUndo||!undoSnapshot||state.over;$('message').textContent=selected>=0?tr('selected'):tr('hint');renderAudioButtons();updateStageHUD();const dailyDot=$('dailyDot');if(dailyDot)dailyDot.style.display=storage.get('nova.daily.completed.'+today())?'none':'block';
 const feverPercent=Math.max(0,Math.min(100,Number(state.fever)||0));
 $('novaFeverFill').style.width=feverPercent+'%';
 $('novaFeverText').textContent=feverPercent+'%';
 renderBoard();renderPieces();}
function notify(text){$('toast').textContent=text;$('toast').classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').classList.remove('show'),1800);}
function placeAt(row,col){if(puzzlePaused||state.over)return;audio.unlock();if(selected<0){notify(tr('hint'));return;}const snapshot=JSON.parse(JSON.stringify(state));const result=state.mode==='classic'?runGlassMove(state,selected,row,col):runMove(state,selected,row,col);if(!result){notify(tr('invalid'));audio.effect('invalid');return;}if(!state.usedUndo)undoSnapshot=snapshot;state=result.state;selected=-1;hover=null;
 if(state.mode==='classic'){
  const fever=advanceFever(snapshot,result.groups,state.combo,result.gained);
  state.fever=fever.fever;state.feverTurns=fever.feverTurns;
  if(fever.bonus)state.score+=fever.bonus;
  if(fever.activated){audio.effect('candy');notify('⚡ NOVA FEVER!');}
 }
 if(state.mode==='stage'){
  state.clears=(snapshot.clears||0)+result.groups;
  state.rows=(snapshot.rows||0)+result.rows;
  state.columns=(snapshot.columns||0)+result.columns;
  state.squares=(snapshot.squares||0)+result.squares;
  state.cellsCleared=(snapshot.cellsCleared||0)+result.cleared;
  state.clearingMoves=(snapshot.clearingMoves||0)+(result.groups>0?1:0);
  state.maxCombo=Math.max(snapshot.maxCombo||0,state.combo||0);
  // Win after real score + special challenges; no artificial game-over required.
  state=applySectorTurn(state,result);
  if(stageWon(state)){
   state.won=true;state.over=true;
   const awarded=awardStage(progress,state.stageLevel,state);
   progress=awarded.progress;lastEarned=awarded.earned;saveProgress();
  }else if(state.over&&stageFailed(state)){state.won=false;}
 }
 saveBest();store();
 const special=state.mode==='stage'?state.specialEvent:null;
 if(special){
  audio.effect(special.kind);
  notify((special.kind==='rocket'?'🚀 ROCKET RUSH!':special.kind==='bomb'?'💣 CANDY BOOM!':'🍬 CANDY POP!')+' +'+(special.bonus||result.gained));
  try{navigator.vibrate?.(special.kind==='bomb'?[26,40,55]:special.kind==='rocket'?[15,24,22]:[12,16,12]);}catch{} 
 }else if(result.groups){notify('🍬 '+tr('nice')+' +'+result.gained);audio.effect('clear');}
 else audio.effect('place');
 render();
 if(special)arcadeEffect($('candyFxLayer'),special);
 else if(result.groups>0)arcadeEffect($('candyFxLayer'),{kind:'combo',center:[row,col],combo:state.combo,bonus:result.gained,groups:result.groups});
 if(state.over){
  if(state.won)audio.effect('victory');else if(state.mode==='stage')audio.effect('gameover');
  gameFinished();if(state.mode==='daily')storage.set('nova.daily.completed.'+today(),'1');
  // Ignore an old victory timer if the player has already restarted or
  // entered another mode. Otherwise a stale modal appears over a new game.
  const finishedState=state;
  setTimeout(()=>{if(state===finishedState&&state.over)showEnd();},special?650:360);
 }
}
function showEnd(){
 $('dialog').classList.toggle('candy-win',state.mode==='stage'&&!!state.won);
 if(state.mode==='stage'){
  const win=!!state.won;
  const messages={
   en:[win?'Stage complete!':'Try again!','Earned ','Nova Points', 'Galaxy map','Retry'],
   fr:[win?'Niveau réussi !':'Réessayez !','Gagné ','Points Nova','Carte galactique','Réessayer'],
   ar:[win?'أكملت المرحلة!':'حاول من جديد!','ربحت ','نقاط نوفا','خريطة المجرات','إعادة المحاولة']
  };
  const [title,earned,points,map,retry]=messages[lang]||messages.en;
  const winTitles={
   en:['🍬 SWEET VICTORY!','🚀 ROCKET MASTER!','🏆 CANDY CHAMPION!'],
   fr:['🍬 VICTOIRE SUCRÉE !','🚀 MAÎTRE DES FUSÉES !','🏆 CHAMPION CANDY !'],
   ar:['🍬 انتصار حلو!','🚀 سيد الصواريخ!','🏆 بطل القنابل!']
  };
  $('dialogTitle').textContent=win?winTitles[lang][state.stageLevel-1]:title;
  $('dialogBody').textContent=win?'★'.repeat(progress.completed[state.stageLevel]||1)+' · '+earned+lastEarned+' '+points:
   '✦ '+stageObjectiveText(state,lang)+' · '+(lang==='ar'?'نفس المرحلة حتى تنجح':lang==='fr'?'Ce niveau reste verrouillé':'Replay this level to unlock the next');
  $('dialogPlay').textContent=win?map:retry;
 }else{
  $('dialogTitle').textContent=tr('gameOver');$('dialogBody').textContent=tr('gameOverBody');
  $('dialogPlay').textContent=tr('playAgain');
 }
 $('dialogScore').textContent=state.score.toLocaleString();$('dialog').hidden=false;
}
function restart(){cancelDrag();audio.effect('new');state=state.mode==='stage'?startStage(state.stageLevel):state.mode==='classic'?makeGlassGame():makeGame(state.mode,today());selected=-1;undoSnapshot=null;lastEarned=0;store();$('dialog').hidden=true;render();}
$('undoBtn').addEventListener('click',()=>{if(!undoSnapshot||state.usedUndo)return;state={...undoSnapshot,usedUndo:true};undoSnapshot=null;audio.unlock();audio.effect('undo');selected=-1;hover=null;store();render();notify(tr('undoUsed'));});
$('newBtn').addEventListener('click',()=>{if(state.moves>0&&!window.confirm(tr('newConfirm')))return;restart();});
$('dialogPlay').addEventListener('click',async()=>{const btn=$('dialogPlay');btn.disabled=true;try{await maybeShowInterstitialOnReplay();}finally{btn.disabled=false;if(state.mode==='stage'&&state.won){$('dialog').hidden=true;galaxy?.open(state.stageLevel+1);}else restart();}});$('dialogClose').addEventListener('click',()=>$('dialog').hidden=true);
document.querySelectorAll('[data-mode]').forEach(btn=>btn.addEventListener('click',()=>{
 if(btn.dataset.mode==='blockfall'){
  audio.unlock();audio.setStage(3);
  falling?.open(12001,{endless:true}); // independent endless falling-block mode
  return;
 }
 setMode(btn.dataset.mode);
 
}));

$('soundBtn').addEventListener('click',()=>{
 audio.unlock();audio.setEffects(!audio.effectsEnabled);
 storage.set('nova.effects',audio.effectsEnabled?'on':'off');
 renderAudioButtons();if(audio.effectsEnabled)audio.effect('pick');
});
$('musicBtn').addEventListener('click',()=>{
 audio.unlock();audio.setMusic(!audio.musicEnabled);
 storage.set('nova.music',audio.musicEnabled?'on':'off');
 renderAudioButtons();
});
$('languageBtn').addEventListener('click',()=>{lang=['en','fr','ar'][(['en','fr','ar'].indexOf(lang)+1)%3];storage.set('nova.lang',lang);render();if(falling?.visible)falling.render();});
$('shareBtn').addEventListener('click',async()=>{const text=`✦ NovaGrid ${state.mode==='daily'?today():''} — ${state.score} points!`;try{if(navigator.share)await navigator.share({text});else if(navigator.clipboard){await navigator.clipboard.writeText(text);notify(tr('copy'));}else notify(text);}catch{}});
document.addEventListener('keydown',e=>{if(e.key==='Escape'){if(puzzlePaused){togglePuzzlePause(false);return;}cancelDrag();galaxy?.close();$('dialog').hidden=true;selected=-1;hover=null;render();}if(/^[1-3]$/.test(e.key)&&state.tray[Number(e.key)-1]){selected=Number(e.key)-1;render();}});
state=readGame('classic');
falling=createBlockfallUI({
 onFinish:()=>{gameFinished();return 0;},
 onExit:()=>{setMode('classic');},
 getLanguage:()=>lang,
 onSound:kind=>{audio.unlock();audio.effect(kind||'pick');},
 onAdBreak:maybeShowInterstitialOnReplay
});
setMode('classic');

void initializeAds();

/* Keep 9x9 board fully visible without page scrolling.
   The real OS status bar is separate, via Capacitor SystemBars and CSS insets. */
let boardFitFrame=0;
function fitBoard(){
 const card=document.getElementById('gamecard');
 if(!card)return;
 const css=getComputedStyle(card);
 const score=card.querySelector('.scorebar');
 const hint=document.getElementById('message');
 const tray=document.getElementById('pieces');
 const actions=card.querySelector('.gametools');
 const board=card.querySelector('.boardwrap');
 if(!score||!hint||!tray||!actions||!board)return;
 const height=element=>element.getBoundingClientRect().height;
 const size=calculateBoardSize({
  cardHeight:card.clientHeight,
  cardWidth:card.clientWidth,
  paddingVertical:(parseFloat(css.paddingTop)||0)+(parseFloat(css.paddingBottom)||0),
  paddingHorizontal:(parseFloat(css.paddingLeft)||0)+(parseFloat(css.paddingRight)||0),
  gap:parseFloat(css.rowGap)||0,
  // IMPORTANT: scorebar and gametools have CLASS names, not IDs.
  fixedHeights:[height(score),height(hint),height(tray),height(actions)],
  margin:12,
  aspectRows:state.board.length,
  aspectCols:state.board[0].length
 });
 document.documentElement.style.setProperty('--board-size',size+'px');
 const shell=document.getElementById('gameShell');
 if(shell){
  const available=shell.getBoundingClientRect().height;
  document.documentElement.classList.toggle('compact-game',available<655);
 }
}
function scheduleBoardFit(){cancelAnimationFrame(boardFitFrame);boardFitFrame=requestAnimationFrame(fitBoard);}
window.addEventListener('resize',scheduleBoardFit);
window.visualViewport?.addEventListener('resize',scheduleBoardFit);
if('ResizeObserver' in window){
 const watcher=new ResizeObserver(scheduleBoardFit);
 watcher.observe(document.getElementById('gamecard'));
 watcher.observe(document.getElementById('gameShell'));
}
document.addEventListener('nova:ads-layout',scheduleBoardFit);
scheduleBoardFit();
