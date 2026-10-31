import {initializeAds,gameFinished,maybeShowInterstitialOnReplay} from './ads.js';
import {SIZE,makeGame,runMove,canPlace,hasMove} from './engine.js';
const T={
 en:{tagline:'A universe of puzzles',eyebrow:'YOUR DAILY BRAIN BOOST',hero1:'Think sharp.',hero2:'Glow brighter.',subtitle:'Place blocks. Clear lines. Chase your next high score.',classic:'Classic',daily:'Daily challenge',score:'SCORE',best:'BEST',streak:'COMBO',hint:'Select a shape, then tap the grid',selected:'Now tap where the shape should land',invalid:'Not enough space! Try another spot',undo:'Undo once',new:'New game',tipTitle:'Cosmic tip',tip:'Fill a row, column or 3×3 square to clear it.',offline:'Offline & private',playAgain:'Play again',close:'Close',gameOver:'Out of space!',gameOverBody:'Every brilliant run starts with another try.',nice:'Cosmic clear!',dailyDone:'Daily challenge completed',newConfirm:'Start a fresh game? Your current progress will be lost.',share:'NovaGrid score',copy:'Score copied!',undoUsed:'Your one undo has been used',none:'Play a move first',dailyLabel:'Daily · '},
 fr:{tagline:'Un univers de puzzles',eyebrow:'LE DÉFI DE VOTRE CERVEAU',hero1:'Pensez vite.',hero2:'Brillez encore.',subtitle:'Placez des blocs. Effacez des lignes. Battez votre record.',classic:'Classique',daily:'Défi du jour',score:'SCORE',best:'RECORD',streak:'COMBO',hint:'Choisissez une pièce, puis touchez la grille',selected:'Touchez une case pour placer la pièce',invalid:'Espace insuffisant !',undo:'Annuler une fois',new:'Nouvelle partie',tipTitle:'Astuce cosmique',tip:'Complétez une ligne, colonne ou carré 3×3.',offline:'Hors ligne et privé',playAgain:'Rejouer',close:'Fermer',gameOver:'Plus de place !',gameOverBody:'Chaque superbe partie commence par un nouvel essai.',nice:'Super combo !',dailyDone:'Défi quotidien terminé',newConfirm:'Recommencer ? Votre progression sera perdue.',share:'Score NovaGrid',copy:'Score copié !',undoUsed:'Annulation déjà utilisée',none:'Jouez d’abord',dailyLabel:'Défi · '},
 ar:{tagline:'عالم من الألغاز',eyebrow:'تحديك الذهني اليومي',hero1:'فكّر بذكاء.',hero2:'وتألّق أكثر.',subtitle:'ضع القطع. امسح الصفوف. حطّم رقمك القياسي.',classic:'الكلاسيكي',daily:'تحدي اليوم',score:'النقاط',best:'الأفضل',streak:'السلسلة',hint:'اختر قطعة ثم اضغط على الشبكة',selected:'اضغط على مكان وضع القطعة',invalid:'لا توجد مساحة كافية!',undo:'تراجع واحد',new:'لعبة جديدة',tipTitle:'نصيحة ذكية',tip:'أكمل صفاً أو عموداً أو مربعاً 3×3 لمسحه.',offline:'دون إنترنت وخصوصي',playAgain:'العب مجدداً',close:'إغلاق',gameOver:'انتهت المساحة!',gameOverBody:'كل محاولة جديدة فرصة لتحطيم الرقم القياسي.',nice:'ممتاز!',dailyDone:'اكتمل تحدي اليوم',newConfirm:'بدء لعبة جديدة؟ سيضيع تقدمك الحالي.',share:'نقاط NovaGrid',copy:'تم نسخ النقاط!',undoUsed:'استخدمت التراجع',none:'العب أولاً',dailyLabel:'يومي · '}
};
const $=id=>document.getElementById(id);const today=()=>new Date().toLocaleDateString('en-CA',{timeZone:'UTC'});
let lang='en';try{lang=localStorage.getItem('nova.lang')||((navigator.language||'en').slice(0,2));}catch{}if(!T[lang])lang='en';
let state,selected=-1,hover=null,undoSnapshot=null,sound=false,toastTimer=0;
const tr=k=>T[lang][k]||T.en[k]||k;
const storage={get(k){try{return localStorage.getItem(k)}catch{return null}},set(k,v){try{localStorage.setItem(k,v)}catch{}}};
function readGame(mode){try{const s=JSON.parse(storage.get(`nova.${mode}`));if(s&&s.board?.length===9&&s.tray?.length===3&&s.mode===mode&&(!s.date||mode!=='daily'||s.date===today()))return s;}catch{}return makeGame(mode,today());}
function store(){storage.set(`nova.${state.mode}`,JSON.stringify(state));}
function bestKey(){return `nova.best.${state.mode}`;}
function best(){return Number(storage.get(bestKey())||0);}
function setMode(mode){if(!['classic','daily'].includes(mode))return;state=readGame(mode);selected=-1;undoSnapshot=null;document.querySelectorAll('[data-mode]').forEach(b=>b.classList.toggle('active',b.dataset.mode===mode));render();}
function saveBest(){if(state.score>best())storage.set(bestKey(),String(state.score));}
function cellClass(r,c){const filled=state.board[r][c];if(filled)return'cell block';const inRegion=(Math.floor(r/3)+Math.floor(c/3))%2===0;let cl='cell'+(inRegion?' region':'');if(selected>=0&&state.tray[selected]&&hover){const shape=state.tray[selected],valid=canPlace(state.board,shape,hover[0],hover[1]);if(shape.some(([dr,dc])=>hover[0]+dr===r&&hover[1]+dc===c))cl+=valid?' preview':' invalid';}return cl;}
function renderBoard(){const board=$('board');board.textContent='';const frag=document.createDocumentFragment();for(let r=0;r<SIZE;r++)for(let c=0;c<SIZE;c++){const el=document.createElement('button');el.type='button';el.className=cellClass(r,c);el.dataset.r=r;el.dataset.c=c;el.setAttribute('role','gridcell');el.setAttribute('aria-label',`Row ${r+1}, column ${c+1}: ${state.board[r][c]?'filled':'empty'}`);el.addEventListener('click',()=>placeAt(r,c));el.addEventListener('pointerenter',()=>{if(selected>=0){hover=[r,c];updateHighlights();}});frag.append(el);}board.append(frag);}
function updateHighlights(){const cells=$('board').children;for(let r=0;r<SIZE;r++)for(let c=0;c<SIZE;c++)cells[r*SIZE+c].className=cellClass(r,c);}
function makePiece(shape){const rows=Math.max(...shape.map(v=>v[0]))+1,cols=Math.max(...shape.map(v=>v[1]))+1;const g=document.createElement('span');g.className='piecegrid';g.style.gridTemplateColumns=`repeat(${cols},var(--micro-size,14px))`;g.style.gridTemplateRows=`repeat(${rows},var(--micro-size,14px))`;const occupied=new Set(shape.map(([r,c])=>`${r},${c}`));for(let r=0;r<rows;r++)for(let c=0;c<cols;c++){const b=document.createElement('span');b.className='micro'+(occupied.has(`${r},${c}`)?'':' blank');g.append(b);}return g;}
function renderPieces(){const area=$('pieces');area.textContent='';state.tray.forEach((shape,i)=>{const el=document.createElement('button');el.type='button';el.className='piece'+(selected===i?' selected':'');el.disabled=!shape||state.over;el.setAttribute('aria-label',`Piece ${i+1}, ${shape?.length??0} blocks`);if(shape)el.append(makePiece(shape));el.addEventListener('click',()=>{selected=i;hover=null;$('message').textContent=tr('selected');renderPieces();updateHighlights();});area.append(el);});}
function render(){document.documentElement.lang=lang;document.documentElement.dir=lang==='ar'?'rtl':'ltr';document.querySelectorAll('[data-i18n]').forEach(el=>{el.textContent=tr(el.dataset.i18n)});$('languageBtn').textContent=lang.toUpperCase()+'⌄';$('score').textContent=state.score.toLocaleString();$('best').textContent=Math.max(best(),state.score).toLocaleString();$('combo').textContent='×'+state.combo;$('undoBtn').disabled=state.usedUndo||!undoSnapshot||state.over;$('message').textContent=selected>=0?tr('selected'):tr('hint');$('soundBtn').textContent=sound?'♪':'♫';$('dailyDot').style.display=storage.get('nova.daily.completed.'+today())?'none':'block';renderBoard();renderPieces();}
function notify(text){$('toast').textContent=text;$('toast').classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').classList.remove('show'),1800);}
function beep(frequency=620){if(!sound)return;try{const Audio=window.AudioContext||window.webkitAudioContext;const ctx=new Audio(),osc=ctx.createOscillator(),gain=ctx.createGain();osc.type='sine';osc.frequency.value=frequency;osc.connect(gain);gain.connect(ctx.destination);gain.gain.setValueAtTime(.035,ctx.currentTime);gain.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+.12);osc.start();osc.stop(ctx.currentTime+.12);osc.onended=()=>ctx.close();}catch{}}
function placeAt(row,col){if(state.over)return;if(selected<0){notify(tr('hint'));return;}const snapshot=JSON.parse(JSON.stringify(state));const result=runMove(state,selected,row,col);if(!result){notify(tr('invalid'));beep(210);return;}if(!state.usedUndo)undoSnapshot=snapshot;state=result.state;selected=-1;hover=null;saveBest();store();if(result.groups){notify(`✦ ${tr('nice')} +${result.gained}`);beep(850);}else beep(500);render();if(state.over){gameFinished();if(state.mode==='daily')storage.set('nova.daily.completed.'+today(),'1');setTimeout(()=>showEnd(),300);}}
function showEnd(){ $('dialogTitle').textContent=tr('gameOver');$('dialogBody').textContent=tr('gameOverBody');$('dialogScore').textContent=state.score.toLocaleString();$('dialog').hidden=false;}
function restart(){state=makeGame(state.mode,today());selected=-1;undoSnapshot=null;store();$('dialog').hidden=true;render();}
$('undoBtn').addEventListener('click',()=>{if(!undoSnapshot||state.usedUndo)return;state={...undoSnapshot,usedUndo:true};undoSnapshot=null;selected=-1;hover=null;store();render();notify(tr('undoUsed'));});
$('newBtn').addEventListener('click',()=>{if(state.moves>0&&!window.confirm(tr('newConfirm')))return;restart();});
$('dialogPlay').addEventListener('click',async()=>{const btn=$('dialogPlay');btn.disabled=true;try{await maybeShowInterstitialOnReplay();}finally{btn.disabled=false;restart();}});$('dialogClose').addEventListener('click',()=>$('dialog').hidden=true);
document.querySelectorAll('[data-mode]').forEach(btn=>btn.addEventListener('click',()=>setMode(btn.dataset.mode)));
$('soundBtn').addEventListener('click',()=>{sound=!sound;render();beep();});
$('languageBtn').addEventListener('click',()=>{lang=['en','fr','ar'][(['en','fr','ar'].indexOf(lang)+1)%3];storage.set('nova.lang',lang);render();});
$('shareBtn').addEventListener('click',async()=>{const text=`✦ NovaGrid ${state.mode==='daily'?today():''} — ${state.score} points!`;try{if(navigator.share)await navigator.share({text});else if(navigator.clipboard){await navigator.clipboard.writeText(text);notify(tr('copy'));}else notify(text);}catch{}});
document.addEventListener('keydown',e=>{if(e.key==='Escape'){$('dialog').hidden=true;selected=-1;hover=null;render();}if(/^[1-3]$/.test(e.key)&&state.tray[Number(e.key)-1]){selected=Number(e.key)-1;render();}});
state=readGame('classic');setMode('classic');

void initializeAds();

/* Keep 9x9 board fully visible without page scrolling.
   The real OS status bar is separate, via Capacitor SystemBars and CSS insets. */
let boardFitFrame=0;
function fitBoard(){
 const card=document.getElementById('gamecard');if(!card)return;
 const style=getComputedStyle(card);
 const pad=(parseFloat(style.paddingTop)||0)+(parseFloat(style.paddingBottom)||0);
 const side=(parseFloat(style.paddingLeft)||0)+(parseFloat(style.paddingRight)||0);
 const gap=parseFloat(style.rowGap)||0;
 const fixed=['scorebar','message','pieces','gametools'].reduce((sum,id)=>{
  const el=document.getElementById(id);return sum+(el?el.getBoundingClientRect().height:0);
 },0);
 const room=Math.max(80,card.clientHeight-pad-fixed-gap*4-12);
 const width=Math.max(80,card.clientWidth-side-5);
 const size=Math.floor(Math.min(room,width,475));
 document.documentElement.style.setProperty('--board-size',size+'px');
}
function scheduleBoardFit(){cancelAnimationFrame(boardFitFrame);boardFitFrame=requestAnimationFrame(fitBoard);}
window.addEventListener('resize',scheduleBoardFit);
window.visualViewport?.addEventListener('resize',scheduleBoardFit);
if('ResizeObserver' in window)new ResizeObserver(scheduleBoardFit).observe(document.getElementById('gamecard'));
scheduleBoardFit();
