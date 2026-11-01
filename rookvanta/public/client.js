/* RookVanta client. The server exclusively determines legal moves and clock results. */
const $=id=>document.getElementById(id);
const glyph={wk:'♔',wq:'♕',wr:'♖',wb:'♗',wn:'♘',wp:'♙',bk:'♚',bq:'♛',br:'♜',bb:'♝',bn:'♞',bp:'♟︎'};
const languages=['en','fr','ar'];
const copy={
 en:{hero:'OWN THE <em>BOARD.</em>',intro:'Real chess. Real rivals. Your next legendary match starts here.',
  create:'Create a match',createInfo:'Challenge a friend from anywhere.',join:'Join a match',joinInfo:'Already got an invite? Enter the code.',
  name:'YOUR CHESS NAME',time:'TIME CONTROL',room:'6-CHARACTER ROOM CODE',createBtn:'CREATE PRIVATE ROOM',joinBtn:'JOIN THE BATTLE',
  joinNote:'Instant connection. No account needed.',lobby:'Lobby',invite:'Invite',match:'The Match',moves:'MOVE HISTORY',empty:'Moves appear here as you play',
  draw:'Offer draw',resign:'Resign',rematch:'Rematch',footer:'RookVanta · Good luck, have fun.',promotion:'Choose a promotion',
  wait:'Waiting for another player. Share the code!',you:'You',opp:'Waiting for rival',connected:'Connected',disconnected:'Disconnected',
  turn:'Your move',theirTurn:'Opponent to move',check:' · Check!',win:'You won',lose:'You lost',drawResult:'Draw',roomCreated:'Room created · share your invite link',
  roomJoined:'Joined match',copied:'Copied to clipboard',notConnected:'Connecting to the server…',
  invalid:'Illegal move',offer:'Draw offered · waiting for reply',drawOffer:'Your opponent offers a draw. Accept?',roomNotFound:'Room not found',
  time:'Time control',globalKicker:'GLOBAL MATCHMAKING',globalTitle:'Play anyone. Anywhere.',globalDescription:'Find a real opponent anywhere in the world automatically. No invite needed.',globalPlay:'PLAY WORLDWIDE',globalCancel:'Cancel search',globalSearching:'SEARCHING WORLDWIDE…',globalWaiting:'players waiting',globalFound:'Opponent found! Starting match…',globalCancelled:'Search cancelled',globalTime:'Searching'},
 fr:{hero:'DOMINEZ <em>L’ÉCHIQUIER.</em>',intro:'De vrais adversaires. Des parties en direct. À vous de jouer.',
  create:'Créer une partie',createInfo:'Défiez un ami où qu’il soit.',join:'Rejoindre',joinInfo:'Vous avez une invitation ? Entrez le code.',
  name:'VOTRE PSEUDO',time:'CADENCE',room:'CODE À 6 CARACTÈRES',createBtn:'CRÉER UN SALON',joinBtn:'REJOINDRE LA PARTIE',
  joinNote:'Connexion immédiate. Aucun compte nécessaire.',lobby:'Accueil',invite:'Inviter',match:'La partie',moves:'COUPS JOUÉS',empty:'Les coups apparaîtront ici',
  draw:'Proposer nulle',resign:'Abandonner',rematch:'Revanche',footer:'RookVanta · Bonne partie !',promotion:'Choisir la promotion',
  wait:'En attente d’un adversaire. Partagez le code !',you:'Vous',opp:'En attente',connected:'Connecté',disconnected:'Déconnecté',
  turn:'À vous de jouer',theirTurn:'Tour de l’adversaire',check:' · Échec !',win:'Vous avez gagné',lose:'Vous avez perdu',drawResult:'Match nul',
  roomCreated:'Salon créé · partagez le lien',roomJoined:'Partie rejointe',copied:'Copié',notConnected:'Connexion au serveur…',
  invalid:'Coup illégal',offer:'Nulle proposée',drawOffer:'Votre adversaire propose la nulle. Accepter ?',roomNotFound:'Salon introuvable',globalKicker:'MATCHMAKING MONDIAL',globalTitle:'Jouez contre le monde.',globalDescription:'Un véritable adversaire partout dans le monde, sans code d’invitation.',globalPlay:'JOUER DANS LE MONDE',globalCancel:'Annuler la recherche',globalSearching:'RECHERCHE EN COURS…',globalWaiting:'joueurs en attente',globalFound:'Adversaire trouvé !',globalCancelled:'Recherche annulée',globalTime:'Recherche'},
 ar:{hero:'سيطر على <em>الرقعة.</em>',intro:'شطرنج حقيقي، خصوم حقيقيون، ومباريات مباشرة حول العالم.',
  create:'إنشاء مباراة',createInfo:'تحدى صديقاً من أي مكان.',join:'الدخول لمباراة',joinInfo:'عندك دعوة؟ دخل رمز الغرفة.',
  name:'اسم اللاعب',time:'مدة المباراة',room:'رمز الغرفة من 6 حروف',createBtn:'إنشاء غرفة خاصة',joinBtn:'دخول للمباراة',
  joinNote:'اتصال مباشر بلا حساب.',lobby:'الرئيسية',invite:'دعوة',match:'المباراة',moves:'النقلات',empty:'النقلات غادي تبان هنا',
  draw:'اقترح التعادل',resign:'استسلام',rematch:'إعادة المباراة',footer:'RookVanta · استمتع باللعب',promotion:'اختار القطعة الجديدة',
  wait:'كنستناو اللاعب الثاني. شارك معاه الرمز!',you:'أنت',opp:'في انتظار الخصم',connected:'متصل',disconnected:'غير متصل',
  turn:'الدور ديالك',theirTurn:'الدور ديال الخصم',check:' · كش!',win:'ربحتي!',lose:'خسرتي',drawResult:'تعادل',
  roomCreated:'تخلقات الغرفة، صيفط رابط الدعوة',roomJoined:'دخلتي للمباراة',copied:'تنسخ الرابط',notConnected:'كنربطو بالسيرفر…',
  invalid:'نقلة ممنوعة',offer:'تقدم عرض التعادل',drawOffer:'الخصم عرض التعادل، واش موافق؟',roomNotFound:'الغرفة ما كايناش',globalKicker:'اللعب العالمي',globalTitle:'لعب مع أي واحد فالعالم.',globalDescription:'السيرفر كيقلب ليك على خصم حقيقي من أي دولة، بلا رمز دعوة.',globalPlay:'العب عالمياً',globalCancel:'إلغاء البحث',globalSearching:'كنقلبو على خصم…',globalWaiting:'لاعبين فالانتظار',globalFound:'لقينا ليك خصم!',globalCancelled:'تلغى البحث',globalTime:'وقت البحث'}
};
let lang=localStorage.getItem('rv.lang')||'en',session=null,state=null,selected=null,promotion=null,timeOption='5+0',lastFen='',animationTime=0,clockTicker=null,lastDrawOffer=null;
let searching=false,searchingSince=0,waitingCount=0;
try{session=JSON.parse(localStorage.getItem('rv.session')||'null');}catch{}
const socket=window.io({autoConnect:true,reconnection:true,timeout:10000});
const t=()=>copy[lang]||copy.en;
function alertUser(message){const el=$('toast');el.textContent=message;el.classList.add('show');clearTimeout(alertUser.timer);alertUser.timer=setTimeout(()=>el.classList.remove('show'),3100);}
function setLanguage(){
 const d=t();
 const translations={heroTitle:d.hero,heroIntro:d.intro,createTitle:d.create,createInfo:d.createInfo,joinTitle:d.join,
  joinInfo:d.joinInfo,nameLabel:d.name,timeLabel:d.time,roomLabel:d.room,createButton:d.createBtn,joinButton:d.joinBtn,
  joinNote:d.joinNote,backLabel:d.lobby,inviteLabel:d.invite,matchTitle:d.match,movesLabel:d.moves,emptyMoves:d.empty,
  drawLabel:d.draw,resignLabel:d.resign,rematchLabel:d.rematch,footerLabel:d.footer,promotionTitle:d.promotion,
  globalKicker:d.globalKicker,globalTitle:d.globalTitle,globalDescription:d.globalDescription,
  globalCancelLabel:d.globalCancel};
 for(const [id,value] of Object.entries(translations)){if(id==='heroTitle')$(id).innerHTML=value;else $(id).textContent=value;}
 $('language').textContent=lang.toUpperCase();
 document.documentElement.lang=lang;
 document.documentElement.dir=lang==='ar'?'rtl':'ltr';
 // Chessboard orientation and file/rank coordinates remain chess standard.
 renderSearch();render();
}
function request(event,data){
 return new Promise(resolve=>{
  if(!socket.connected){alertUser(t().notConnected);resolve({ok:false});return;}
  socket.timeout(7000).emit(event,data,(err,res)=>resolve(err?{ok:false,error:'Network timeout'}:res));
 });
}
function renderSearch(){
 const d=t();
 $('globalPlayLabel').textContent=searching?d.globalSearching:d.globalPlay;
 $('globalPlay').classList.toggle('searching',searching);
 $('globalPlay').disabled=searching||!socket.connected;
 $('globalCancel').hidden=!searching;
 $('globalPopulation').textContent=waitingCount+' '+d.globalWaiting;
 $('globalTimer').hidden=!searching;
 if(searching){
  const seconds=Math.floor((Date.now()-searchingSince)/1000);
  $('globalTimer').textContent=d.globalTime+': '+String(Math.floor(seconds/60)).padStart(2,'0')+':'+String(seconds%60).padStart(2,'0');
 }
}
async function globalSearch(){
 if(searching||!socket.connected)return;
 searching=true;searchingSince=Date.now();renderSearch();
 const reply=await request('matchmaking:search',{name:$('playerName').value||'Player',time:timeOption});
 if(!reply?.ok){
  searching=false;renderSearch();alertUser(reply?.error||'Unable to find opponents');return;
 }
 if(reply.status==='matched'){
  searching=false;renderSearch();enterRoom(reply);alertUser(t().globalFound);
 }
}
async function cancelSearch(){
 if(!searching)return;
 // Cancel locally first to prevent delayed match responses from duplicating UI transitions.
 searching=false;renderSearch();
 const response=await request('matchmaking:cancel',{});
 if(response.ok)alertUser(t().globalCancelled);
}
function saveSession(p){session=p;localStorage.setItem('rv.session',JSON.stringify(p));}
function enterRoom(res){
 if(!res?.ok){alertUser(res?.error||t().roomNotFound);return;}
 searching=false;renderSearch();
 saveSession({code:res.code,token:res.token,color:res.color});
 const url=new URL(location.href);url.searchParams.set('room',res.code);history.replaceState(null,'',url);
 $('lobby').hidden=true;$('arena').hidden=false;
 $('roomBadge').textContent=res.code;$('roomCodeValue').textContent=res.code;
 selected=null;render();alertUser(t().roomJoined);
}
async function create(){
 if(searching)await cancelSearch();
 const res=await request('room:create',{name:$('playerName').value||'Player',time:timeOption});enterRoom(res);
 if(res?.ok)alertUser(t().roomCreated);
}
async function join(){
 if(searching)await cancelSearch();
 const code=$('roomCode').value.trim().toUpperCase().replace(/[^A-Z0-9]/g,'');
 if(code.length!==6){alertUser('Enter a 6-character room code');return;}
 const reuse=session?.code===code?session.token:null;
 enterRoom(await request('room:join',{code,name:$('playerName').value||'Player',token:reuse}));
}
function formatTime(ms){const s=Math.max(0,Math.ceil(ms/1000));return String(Math.floor(s/60)).padStart(2,'0')+':'+String(s%60).padStart(2,'0');}
function elapsedClock(color){
 if(!state)return 0;
 const rem=state.clocks?.[color]??300000;
 if(state.started&&!state.result&&state.turn===color)return Math.max(0,rem-(Date.now()-state.serverTime));
 return rem;
}
function renderClocks(){
 if(!state||!session)return;
 const mine=session.color,other=mine==='w'?'b':'w';
 for(const [id,color] of [['meClock',mine],['opponentClock',other]]){
  $(id).textContent=formatTime(elapsedClock(color));
  $(id).classList.toggle('active',state.started&&!state.result&&state.turn===color);
  $(id).classList.toggle('danger',elapsedClock(color)<30000);
 }
}
function parseBoard(fen){
 return fen.split(' ')[0].split('/').map(row=>{
  const out=[];for(const piece of row){if(/[1-8]/.test(piece))for(let i=0;i<Number(piece);i++)out.push(null);
   else out.push({color:piece===piece.toUpperCase()?'w':'b',kind:piece.toLowerCase()});}
  return out;
 });
}
function moveInfo(){return state?.history?.length?state.history.length:0;}
function drawBoard(){
 const board=$('board');if(!state||!session)return;
 const pos=parseBoard(state.fen),white=session.color==='w',file='abcdefgh';
 const moveCount=moveInfo(),fromIndex=moveCount?null:null;
 const ranks=white?[8,7,6,5,4,3,2,1]:[1,2,3,4,5,6,7,8];
 const files=white?[...file]:[...file].reverse();
 const candidates=state.legalMoves||[];
 const legalTargets=new Set(selected?candidates.filter(m=>m.from===selected).map(m=>m.to):[]);
 const fragment=document.createDocumentFragment();
 for(const [ri,rank] of ranks.entries())for(const [fi,col] of files.entries()){
  const realRow=8-rank,realCol=file.indexOf(col),piece=pos[realRow][realCol],square=col+rank;
  const button=document.createElement('button');button.type='button';
  button.className='square '+(((realRow+realCol)%2===0)?'light':'dark')+(selected===square?' selected':'');
  const checker=state.check&&state.turn===piece?.color&&piece.kind==='k';
  if(checker)button.classList.add('check');
  button.dataset.square=square;button.setAttribute('role','gridcell');
  button.setAttribute('aria-label',square+' '+(piece?piece.color+' '+piece.kind:'empty'));
  if(piece){const span=document.createElement('span');span.className='piece '+(piece.color==='w'?'white':'black');span.textContent=glyph[piece.color+piece.kind];button.append(span);}
  if(legalTargets.has(square)){const mark=document.createElement('span');mark.className=piece?'capture':'dot';button.append(mark);}
  if(fi===0){const n=document.createElement('span');n.className='coord rank';n.textContent=rank;button.append(n);}
  if(ri===7){const n=document.createElement('span');n.className='coord file';n.textContent=col;button.append(n);}
  button.addEventListener('click',()=>onSquare(square,piece));
  fragment.append(button);
 }
 board.replaceChildren(fragment);
}
function promotionChoice(from,to,choices){
 promotion={from,to};
 const container=$('promotionOptions');container.replaceChildren();
 for(const p of ['q','r','b','n']){
  if(!choices.some(m=>m.promotion===p))continue;
  const b=document.createElement('button');b.textContent=glyph[(session.color||'w')+p];b.title=p;
  b.addEventListener('click',()=>{const move=promotion;promotion=null;$('promotionDialog').hidden=true;submitMove({...move,promotion:p});});
  container.append(b);
 }
 $('promotionDialog').hidden=false;
}
async function submitMove({from,to,promotion='q'}){
 const reply=await request('room:move',{from,to,promotion});
 if(!reply?.ok)alertUser(reply?.error||t().invalid);
 selected=null;render();
}
function onSquare(square,piece){
 if(!state||state.result||!state.started||session?.color!==state.turn)return;
 const legal=state.legalMoves||[];
 if(selected){
  const candidates=legal.filter(m=>m.from===selected&&m.to===square);
  if(candidates.length){
   if(candidates.some(m=>m.promotion)){promotionChoice(selected,square,candidates);return;}
   const start=selected;selected=null;submitMove({from:start,to:square});return;
  }
 }
 if(piece?.color===session.color&&legal.some(m=>m.from===square))selected=selected===square?null:square;
 else selected=null;
 drawBoard();
}
function gameMessage(){
 if(!state)return t().wait;
 if(!state.started)return t().wait;
 if(state.result){
  if(!state.result.winner)return t().drawResult+' · '+state.result.reason;
  return (state.result.winner===session.color?t().win:t().lose)+' · '+state.result.reason;
 }
 return (state.turn===session.color?t().turn:t().theirTurn)+(state.check?t().check:'');
}
function renderHistory(){
 if(!state)return;
 const list=$('moveList'),moves=state.history||[];
 $('moveCount').textContent=moves.length+' MOVES';
 list.replaceChildren();
 if(!moves.length){
  const div=document.createElement('div');div.className='empty-moves';div.textContent=t().empty;list.append(div);return;
 }
 const frag=document.createDocumentFragment();
 for(let i=0;i<moves.length;i+=2){
  const row=document.createElement('div');row.className='move-pair';
  for(const val of [String(Math.floor(i/2)+1)+'.',moves[i],moves[i+1]||'—']){
   const span=document.createElement('span');span.textContent=val;row.append(span);
  }
  frag.append(row);
 }
 list.append(frag);list.scrollTop=list.scrollHeight;
}
function render(){
 if(!state||$('arena').hidden)return;
 const mine=state.players?.find(x=>x?.color===session.color),op=state.players?.find(x=>x&&x.color!==session.color);
 $('meName').textContent=(mine?.name||t().you)+' ('+(session.color==='w'?'White':'Black')+')';
 $('opponentName').textContent=op?.name||t().opp;
 $('meStatus').textContent=t().you+' · '+(mine?.online?t().connected:t().disconnected);
 $('opponentStatus').textContent=op?(op.online?t().connected:t().disconnected):t().wait;
 $('matchStatus').textContent=gameMessage();
 $('roomBadge').textContent=state.code;$('roomCodeValue').textContent=state.code;
 $('draw').disabled=!!state.result||!state.started;
 $('resign').disabled=!!state.result||!state.started;
 $('rematch').hidden=!state.result;
 drawBoard();renderHistory();renderClocks();
 if(state.drawOffer&&state.drawOffer!==session.color&&state.drawOffer!==lastDrawOffer){
  lastDrawOffer=state.drawOffer;
  if(confirm(t().drawOffer))request('room:draw',{action:'accept'});
  else request('room:draw',{action:'decline'});
 }
 if(!state.drawOffer)lastDrawOffer=null;
}
function inviteUrl(){
 const u=new URL(location.href);u.searchParams.set('room',session?.code||'');return u.href;
}
async function copyText(text){
 try{await navigator.clipboard.writeText(text);alertUser(t().copied);}
 catch{window.prompt('Copy link',text);}
}
socket.on('connect',async()=>{
 $('connectionLabel').textContent='ONLINE';document.querySelector('.live-pill').classList.add('online');renderSearch();
 if(session?.code&&session?.token){
  const res=await request('room:join',{code:session.code,token:session.token,name:$('playerName').value||'Player'});
  if(res?.ok)enterRoom(res);
  else{session=null;localStorage.removeItem('rv.session');}
 }
});
socket.on('disconnect',()=>{$('connectionLabel').textContent='OFFLINE';document.querySelector('.live-pill').classList.remove('online');if(searching){searching=false;alertUser('Disconnected. Search again to find a match.');}renderSearch();});
socket.on('matchmaking:population',data=>{waitingCount=Math.max(0,Number(data?.byTime?.[timeOption]||0));renderSearch();});
socket.on('matchmaking:found',match=>{
 searching=false;renderSearch();enterRoom({...match,ok:true});alertUser(t().globalFound);
});
socket.on('room:replaced',()=>{state=null;session=null;localStorage.removeItem('rv.session');$('arena').hidden=true;$('lobby').hidden=false;alertUser('This room was resumed on another device.');});
socket.on('room:state',payload=>{
 state=payload;
 if(selected&&!state.legalMoves?.some(m=>m.from===selected))selected=null;
 render();
});
$('create').addEventListener('click',create);$('join').addEventListener('click',join);
$('globalPlay').addEventListener('click',globalSearch);
$('globalCancel').addEventListener('click',cancelSearch);
$('roomCode').addEventListener('keydown',e=>{if(e.key==='Enter')join();});
document.querySelectorAll('[data-time]').forEach(b=>b.addEventListener('click',()=>{
 timeOption=b.dataset.time;waitingCount=0;renderSearch();
 document.querySelectorAll('[data-time]').forEach(x=>{x.classList.toggle('active',x===b);x.setAttribute('aria-pressed',String(x===b));});
}));
$('back').addEventListener('click',()=>{$('arena').hidden=true;$('lobby').hidden=false;});
$('copyLink').addEventListener('click',async()=>{
 if(navigator.share){try{await navigator.share({title:'RookVanta Chess',url:inviteUrl()});return;}catch{}}
 copyText(inviteUrl());
});
$('copyCode').addEventListener('click',()=>copyText(state?.code||session?.code||''));
$('resign').addEventListener('click',async()=>{if(confirm('Resign from this match?')){const r=await request('room:resign',{});if(!r.ok)alertUser(r.error);}});
$('draw').addEventListener('click',async()=>{const r=await request('room:draw',{action:'offer'});alertUser(r.ok?t().offer:r.error);});
$('rematch').addEventListener('click',async()=>{const r=await request('room:rematch',{});alertUser(r.ok?'Rematch requested':r.error);});
$('promotionCancel').addEventListener('click',()=>{promotion=null;$('promotionDialog').hidden=true;});
$('language').addEventListener('click',()=>{lang=languages[(languages.indexOf(lang)+1)%languages.length];localStorage.setItem('rv.lang',lang);setLanguage();});
const invite=new URL(location.href).searchParams.get('room');
if(invite)$('roomCode').value=invite.toUpperCase().slice(0,6);
$('playerName').value=localStorage.getItem('rv.name')||'';
$('playerName').addEventListener('change',()=>localStorage.setItem('rv.name',$('playerName').value.slice(0,24)));
setLanguage();
clockTicker=setInterval(()=>{if(state&&!$('arena').hidden)renderClocks();if(searching)renderSearch();},250);
