/* NovaGrid Galaxies: 12,000 deterministic stages, six genuinely different sectors.
   All progression stays on device. The first 2,000 levels and historical progress
   remain compatible with the original NovaGrid campaign. */
import {makeGame,seededRng,hashDate,hasMove,drawTray,PATTERNS,anyPlacement} from './engine.js';
export const WORLD_SIZE=100;
export const WORLDS_PER_SECTOR=20;
export const SECTOR_SIZE=WORLD_SIZE*WORLDS_PER_SECTOR;
export const SECTORS=[
 {id:'explorer',icon:'✦',name:{en:'Cosmic Explorer',fr:'Exploration cosmique',ar:'الاستكشاف الكوني'},
  philosophy:{en:'Classic placement and eight evolving missions',fr:'Placement classique et huit missions',ar:'الوضع الكلاسيكي وثمانية تحديات'}},
 {id:'meteor',icon:'☄',name:{en:'Meteor Storm',fr:'Tempête de météores',ar:'عاصفة النيازك'},
  philosophy:{en:'New blocks fall into the grid during play',fr:'Des météores envahissent la grille',ar:'نيازك جديدة كتهبط داخل الشبكة'}},
 {id:'gravity',icon:'⬇',name:{en:'Gravity Forge',fr:'Forge gravitationnelle',ar:'مصنع الجاذبية'},
  philosophy:{en:'Every turn pulls the board downward',fr:'La gravité attire les blocs vers le bas',ar:'كل حركة كتهبط القطع للأسفل'}},
 {id:'prism',icon:'◈',name:{en:'Prism Temple',fr:'Temple des prismes',ar:'معبد الكريستال'},
  philosophy:{en:'3×3 squares charge the prism and earn bonuses',fr:'Les carrés 3×3 chargent les prismes',ar:'المربعات 3×3 كتشحن البلورات وكتعطي مكافآت'}},
 {id:'reactor',icon:'⚡',name:{en:'Chain Reactor',fr:'Réacteur des combos',ar:'مفاعل السلاسل'},
  philosophy:{en:'Chain clears power score boosts and clearing pulses',fr:'Les combos créent des impulsions',ar:'السلاسل كتولد طاقة ومسح إضافي'}},
 {id:'void',icon:'◉',name:{en:'Void Trials',fr:'Épreuves du vide',ar:'تحديات الفراغ'},
  philosophy:{en:'Gravity and meteors together, with boss stages',fr:'Gravité et météores avec des boss',ar:'الجاذبية والنيازك مع مراحل الزعماء'}}
];
export const TOTAL_WORLDS=SECTORS.length*WORLDS_PER_SECTOR;
export const TOTAL_STAGES=TOTAL_WORLDS*WORLD_SIZE;
const baseNames=[
 'Nebula Dawn','Aurora Fields','Comet Trail','Lunar Grove','Starlight Harbor',
 'Crystal Orbit','Violet Rift','Meteor Garden','Solar Temple','Quantum Vale',
 'Titan Rings','Nova Cascade','Celestial Reef','Photon Horizon','Gravity Wells',
 'Cosmic Bloom','Eclipse Passage','Hypernova Path','Infinity Gate','Astral Crown'
];
const adjectives=['Blazing','Iron','Falling','Amber','Silent','Electric','Radiant','Twilight','Frozen','Golden','Storm','Orbiting','Ancient','Rising','Shifting','Hidden','Luminous','Eternal','Crimson','Boundless'];
const themes=['Comet','Gravity','Prism','Reactor','Void'];
export const WORLD_NAMES=baseNames.concat(themes.flatMap(theme=>adjectives.map(a=>a+' '+theme)));
export const WORLD_SYMBOLS=Array.from({length:TOTAL_WORLDS},(_,i)=>SECTORS[Math.floor(i/WORLDS_PER_SECTOR)].icon);
export const MISSION_TYPES=['score','rows','columns','squares','combo','survival','clearing','mastery','charge'];
const sectorKinds={
 explorer:MISSION_TYPES.filter(k=>k!=='charge'),
 meteor:['survival','clearing','rows','mastery','score'],
 gravity:['columns','clearing','survival','score','mastery'],
 prism:['squares','charge','clearing','score','mastery'],
 reactor:['combo','charge','mastery','score','clearing'],
 void:['survival','mastery','charge','rows','columns','squares']
};
export function stageConfig(level){
 if(!Number.isInteger(level)||level<1||level>TOTAL_STAGES)throw new RangeError('Invalid NovaGrid stage');
 const sector=Math.floor((level-1)/SECTOR_SIZE),section=SECTORS[sector],local=(level-1)%SECTOR_SIZE;
 const world=Math.floor((level-1)/WORLD_SIZE);
 // Keep the first 2,000 campaign tiers identical to the original release.
 const tier=sector===0?Math.min(10,Math.floor(local/115)):Math.min(11,Math.floor(local/155));
 const difficulty=tier+sector*2;
 const kinds=sectorKinds[section.id],kind=kinds[local%kinds.length];
 const objectives={
  score:80+difficulty*28,
  rows:1+Math.min(3,Math.floor(difficulty/4)),
  columns:1+Math.min(3,Math.floor(difficulty/4)),
  squares:1+Math.min(3,Math.floor(difficulty/4)),
  combo:2+Math.min(2,Math.floor(difficulty/7)),
  survival:8+Math.min(15,difficulty),
  clearing:18+9*Math.min(7,Math.floor(difficulty/3)),
  mastery:2+Math.min(4,Math.floor(difficulty/5)),
  charge:2+Math.min(5,Math.floor(difficulty/3))
 };
 return {level,world,sector,sectorId:section.id,sectorName:section.name,ordinal:(level-1)%WORLD_SIZE+1,
  kind,goal:objectives[kind],target:objectives[kind],minMoves:6+Math.min(6,Math.floor(difficulty/3)),
  scoreBonus:kind==='mastery'?100+difficulty*20:0,
  unlockCost:local===0?0:100+Math.min(80,Math.floor(local/40)*2),
  layout:(level-1)%6,tier,sectorDifficulty:difficulty,
  hazardEvery:section.id==='void'?2:section.id==='meteor'?3:0,
  gravity:section.id==='gravity'||section.id==='void',
  boss:section.id==='void'&&(local+1)%25===0
 };
}
export function initialProgress(){return {version:3,coins:0,unlocked:1,unlockedSectors:SECTORS.map((_,i)=>i*SECTOR_SIZE+1),completed:{},totalEarned:0};}
export function normalizeProgress(value){
 const p=initialProgress();
 if(!value||typeof value!=='object')return p;
 const coins=Number(value.coins),unlocked=Number(value.unlocked);
 p.coins=Number.isSafeInteger(coins)&&coins>=0?Math.min(99999999,coins):0;
 p.unlocked=Number.isInteger(unlocked)?Math.max(1,Math.min(SECTOR_SIZE,unlocked)):1;
 if(Array.isArray(value.unlockedSectors)){
  p.unlockedSectors=p.unlockedSectors.map((first,i)=>{
   const valueAt=Number(value.unlockedSectors[i]);
   return Number.isInteger(valueAt)?Math.max(first,Math.min(first+SECTOR_SIZE-1,valueAt)):first;
  });
 }
 p.unlockedSectors[0]=Math.max(p.unlocked,p.unlockedSectors[0]);
 p.unlocked=p.unlockedSectors[0]; // compatibility for the first 2,000 stage legacy save
 if(value.completed&&typeof value.completed==='object'){
  for(const [key,stars] of Object.entries(value.completed)){
   const lvl=Number(key);
   if(Number.isInteger(lvl)&&lvl>0&&lvl<=TOTAL_STAGES&&String(lvl)===key&&isStageUnlocked(p,lvl)){
    p.completed[key]=Math.min(3,Math.max(0,Math.floor(Number(stars)||0)));
   }
  }
 }
 p.totalEarned=Number.isSafeInteger(value.totalEarned)&&value.totalEarned>=0?value.totalEarned:0;
 return p;
}
export function isStageUnlocked(progress,level){
 if(!Number.isInteger(level)||level<1||level>TOTAL_STAGES)return false;
 const sec=Math.floor((level-1)/SECTOR_SIZE);
 const arr=progress?.unlockedSectors;
 const ceiling=Array.isArray(arr)?Number(arr[sec]):sec===0?Number(progress?.unlocked):sec*SECTOR_SIZE+1;
 return level<=ceiling;
}
export function stageBoard(level){
 const cfg=stageConfig(level),rng=seededRng(hashDate('nova-galaxy-geometry-'+level));
 const board=Array.from({length:9},()=>Array(9).fill(0));
 const add=(r,c)=>{if(r>=0&&c>=0&&r<9&&c<9)board[r][c]=1;};
 if(level===1)return board;
 const count=3+cfg.tier+(cfg.layout%3)+cfg.sector;
 if(cfg.kind==='rows'){const row=Math.floor(rng()*9);for(let i=0;i<Math.min(7,count+2);i++)add(row,(i*2+cfg.layout)%9);}
 else if(cfg.kind==='columns'){const col=Math.floor(rng()*9);for(let i=0;i<Math.min(7,count+2);i++)add((i*2+cfg.layout)%9,col);}
 else if(cfg.kind==='squares'||cfg.sectorId==='prism'){
  const y=Math.floor(rng()*3)*3,x=Math.floor(rng()*3)*3;
  for(let i=0;i<Math.min(7,count+2);i++)add(y+Math.floor(i/3),x+i%3);
 }else if(cfg.kind==='combo'||cfg.sectorId==='reactor'){
  const row=Math.floor(rng()*9),col=Math.floor(rng()*9);
  for(let i=0;i<5;i++){add(row,(i*2)%9);add((i*2+1)%9,col);}
 }else if(cfg.kind==='clearing'){
  const row=Math.floor(rng()*9);for(let i=0;i<6;i++)add(row,(i+cfg.layout)%9);
 }else{
  for(let i=0;i<count;i++)add(Math.floor(rng()*9),Math.floor(rng()*9));
 }
 for(let i=0;i<Math.floor(cfg.tier/2)+((cfg.boss)?5:0);i++)add(Math.floor(rng()*9),Math.floor(rng()*9));
 return board;
}
/* Distinct shape economies: all sections still guarantee one playable piece. */
export function drawSectorTray(level,board,round=0){
 const cfg=stageConfig(level);
 if(cfg.sectorId==='explorer')return drawTray(seededRng(hashDate('nova-stage-'+level+'-'+round)),board);
 const rng=seededRng(hashDate('nova-sector-tray-'+level+'-'+round));
 const dims=p=>({h:Math.max(...p.map(c=>c[0]))+1,w:Math.max(...p.map(c=>c[1]))+1});
 const filters={
  meteor:p=>p.length>=3&&p.length<=6,
  gravity:p=>p.length>=2&&dims(p).h>=dims(p).w,
  prism:p=>p.length>=3&&dims(p).h<=3&&dims(p).w<=3,
  reactor:p=>p.length>=3&&p.length<=6,
  void:p=>p.length>=4
 };
 const choices=PATTERNS.filter(filters[cfg.sectorId]||(()=>true));
 const pool=choices.length?choices:PATTERNS;
 const tray=Array.from({length:3},()=>pool[Math.floor(rng()*pool.length)].map(c=>[...c]));
 if(!hasMove(board,tray)){
  const playable=PATTERNS.filter(p=>anyPlacement(board,p));
  if(playable.length)tray[Math.floor(rng()*3)]=playable[Math.floor(rng()*playable.length)].map(c=>[...c]);
 }
 return tray;
}
export function startStage(level){
 const cfg=stageConfig(level),date='nova-stage-'+level,game=makeGame('daily',date);
 const board=stageBoard(level);
 const specialized=cfg.sectorId==='explorer'?game.tray:drawSectorTray(level,board,0);
 const tray=hasMove(board,specialized)?specialized:drawTray(seededRng(hashDate(date+'-tray')),board);
 return {...game,board,tray,mode:'stage',stageLevel:level,clears:0,rows:0,columns:0,
  squares:0,cellsCleared:0,maxCombo:0,clearingMoves:0,charge:0,meteorHits:0,
  date,won:false,over:false,sectorId:cfg.sectorId};
}
export function collapseBoard(board){
 const next=board.map(row=>[...row]);
 for(let c=0;c<9;c++){const occupied=board.reduce((n,row)=>n+Number(!!row[c]),0);
  for(let r=0;r<9;r++)next[r][c]=r>=9-occupied?1:0;
 }
 return next;
}
function meteorStrike(board,seed,moves,n=1){
 const free=[];
 for(let r=0;r<9;r++)for(let c=0;c<9;c++)if(!board[r][c])free.push([r,c]);
 const rng=seededRng(hashDate('nova-meteor-'+seed+'-'+moves));
 const next=board.map(row=>[...row]);
 for(let i=0;i<n&&free.length;i++){
  const j=Math.floor(rng()*free.length),[r,c]=free.splice(j,1)[0];next[r][c]=1;
 }
 return next;
}
export function applySectorTurn(state,result){
 if(state.mode!=='stage')return state;
 const cfg=stageConfig(state.stageLevel);
 let next={...state};
 // Refill the tray using this division's shape strategy on each new round.
 if(cfg.sectorId!=='explorer'&&next.moves>0&&next.moves%3===0&&next.tray.every(Boolean))
  next.tray=drawSectorTray(next.stageLevel,next.board,next.moves/3);
 if(cfg.sectorId==='prism'&&result.squares){
  next.score+=result.squares*25;
  next.charge=(state.charge||0)+result.squares;
 }
 if(cfg.sectorId==='reactor'&&result.groups){
  next.charge=(state.charge||0)+result.groups;
  next.score+=result.groups*(12+Math.min(5,next.combo||0)*4);
  if(next.charge%3===0){
   // Clearing pulse creates more breathing space, but it cannot complete
   // objectives automatically: only result.groups counts as a player clear.
   const board=next.board.map(row=>[...row]);
   let removed=0;
   for(let r=0;r<9&&removed<3;r++)for(let c=0;c<9&&removed<3;c++)
    if(board[r][c]&&(r+c+next.moves)%3===0){board[r][c]=0;removed++;}
   next.board=board;
  }
 }
 if(cfg.sectorId==='void'&&result.groups)next.charge=(state.charge||0)+result.groups;
 if(cfg.gravity)next.board=collapseBoard(next.board);
 if(cfg.hazardEvery&&next.moves%cfg.hazardEvery===0){
  next.board=meteorStrike(next.board,next.seed,next.moves,cfg.boss?2:1);
  next.meteorHits=(state.meteorHits||0)+(cfg.boss?2:1);
 }
 next.over=!hasMove(next.board,next.tray);
 return next;
}
export function objectiveValue(state,cfg=stageConfig(state.stageLevel)){
 switch(cfg.kind){
  case 'score':return state.score||0;
  case 'rows':return state.rows||0;
  case 'columns':return state.columns||0;
  case 'squares':return state.squares||0;
  case 'combo':return state.maxCombo||0;
  case 'survival':return state.moves||0;
  case 'clearing':return state.cellsCleared||0;
  case 'mastery':return state.clears||0;
  case 'charge':return state.charge||0;
  default:return 0;
 }
}
const LABELS={
 en:{score:'Score',rows:'Rows cleared',columns:'Columns cleared',squares:'3×3 cleared',combo:'Best chain',survival:'Placements',clearing:'Blocks removed',mastery:'Groups cleared',charge:'Energy charged',finish:'Play until no shapes fit'},
 fr:{score:'Score',rows:'Lignes effacées',columns:'Colonnes effacées',squares:'Carrés 3×3',combo:'Meilleure série',survival:'Pièces posées',clearing:'Blocs effacés',mastery:'Groupes effacés',charge:'Énergie chargée',finish:'Jouez jusqu’à épuisement'},
 ar:{score:'النقاط',rows:'صفوف ممسوحة',columns:'أعمدة ممسوحة',squares:'مربعات 3×3',combo:'أفضل سلسلة',survival:'قطع موضوعة',clearing:'مربعات ممسوحة',mastery:'مجموعات ممسوحة',charge:'الطاقة المشحونة',finish:'كمّل حتى ما يبقى حتى حل'}
};
export function stageObjectiveText(state,lang='en'){
 const cfg=stageConfig(state.stageLevel),t=LABELS[lang]||LABELS.en;
 const base=t[cfg.kind]+' '+objectiveValue(state,cfg)+'/'+cfg.goal;
 return cfg.kind==='mastery'?base+' · '+t.score+' '+(state.score||0)+'/'+cfg.scoreBonus:base;
}
export function stageWon(state){
 if(state.mode!=='stage'||!state.over)return false; // only resolve after a real puzzle run
 const cfg=stageConfig(state.stageLevel);
 return (state.moves||0)>=cfg.minMoves&&objectiveValue(state,cfg)>=cfg.goal&&
  (cfg.kind!=='mastery'||state.score>=cfg.scoreBonus);
}
export function stageFailed(state){return state.mode==='stage'&&!!state.over&&!stageWon(state);}
export function rankStage(state){
 if(!stageWon(state))return 0;
 const cfg=stageConfig(state.stageLevel),ratio=objectiveValue(state,cfg)/cfg.goal;
 return ratio>=2.25&&state.score>=cfg.scoreBonus?3:ratio>=1.45?2:1;
}
export function awardStage(progress,level,finishedState){
 const p=normalizeProgress(progress);
 if(!isStageUnlocked(p,level)||finishedState?.stageLevel!==level||!stageWon(finishedState))return {progress:p,earned:0};
 const stars=rankStage(finishedState),prev=p.completed[level]||0;
 if(stars<=prev)return {progress:p,earned:0};
 const earned=prev===0?150+25*stars:15*(stars-prev);
 p.completed[level]=stars;p.coins+=earned;p.totalEarned+=earned;
 return {progress:p,earned};
}
export function purchaseStage(progress,level){
 const p=normalizeProgress(progress);
 if(!Number.isInteger(level)||level<2||level>TOTAL_STAGES)return {progress:p,ok:false,reason:'invalid'};
 if(isStageUnlocked(p,level))return {progress:p,ok:true,cost:0};
 const sec=Math.floor((level-1)/SECTOR_SIZE);
 if(level!==p.unlockedSectors[sec]+1||!(p.completed[level-1]>0))return {progress:p,ok:false,reason:'progress'};
 const cost=stageConfig(level).unlockCost;
 if(p.coins<cost)return {progress:p,ok:false,reason:'coins',cost};
 p.coins-=cost;p.unlockedSectors[sec]=level;p.unlocked=p.unlockedSectors[0];
 return {progress:p,ok:true,cost};
}
export function progressSummary(progress){
 const p=normalizeProgress(progress);
 return {completed:Object.values(p.completed).filter(v=>v>0).length,
  stars:Object.values(p.completed).reduce((a,b)=>a+b,0),
  coins:p.coins,unlocked:p.unlocked,unlockedSectors:p.unlockedSectors};
}
