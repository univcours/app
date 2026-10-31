/* NovaGrid Galaxies: 2,000 deterministic campaigns, eight distinct mission rules.
   IMPORTANT: a mission is judged only when the player has NO playable shapes.
   Playing well can fulfil the target early but never ends a run early. */
import {makeGame,seededRng,hashDate,hasMove,drawTray} from './engine.js';
export const WORLD_SIZE=100;
export const TOTAL_WORLDS=20;
export const TOTAL_STAGES=WORLD_SIZE*TOTAL_WORLDS;
export const WORLD_NAMES=[
 'Nebula Dawn','Aurora Fields','Comet Trail','Lunar Grove','Starlight Harbor',
 'Crystal Orbit','Violet Rift','Meteor Garden','Solar Temple','Quantum Vale',
 'Titan Rings','Nova Cascade','Celestial Reef','Photon Horizon','Gravity Wells',
 'Cosmic Bloom','Eclipse Passage','Hypernova Path','Infinity Gate','Astral Crown'
];
export const WORLD_SYMBOLS=['✦','☄','✧','☽','✺','◈','✴','❖','☀','◇','♄','✷','✧','✺','◎','✿','☾','★','∞','♛'];
export const MISSION_TYPES=['score','rows','columns','squares','combo','survival','clearing','mastery'];
export function stageConfig(level){
 if(!Number.isInteger(level)||level<1||level>TOTAL_STAGES)throw new RangeError('Invalid NovaGrid stage');
 const world=Math.floor((level-1)/WORLD_SIZE),tier=Math.min(10,Math.floor((level-1)/115));
 const kind=MISSION_TYPES[(level-1)%MISSION_TYPES.length];
 const objectives={
  score:80+tier*28,
  rows:1+Math.min(2,Math.floor(tier/3)),
  columns:1+Math.min(2,Math.floor(tier/3)),
  squares:1+Math.min(2,Math.floor(tier/3)),
  combo:2+Math.min(1,Math.floor(tier/5)),
  survival:8+Math.min(10,tier),
  clearing:9*(2+Math.min(4,Math.floor(tier/2))),
  mastery:2+Math.min(2,Math.floor(tier/4))
 };
 return {
  level,world,ordinal:(level-1)%WORLD_SIZE+1,
  kind,goal:objectives[kind],
  minMoves:6+Math.min(5,Math.floor(tier/2)),
  scoreBonus:kind==='mastery'?100+tier*20:0,
  // "target" retained for old data compatibility; actual goal differs by kind.
  target:objectives[kind],
  unlockCost:level===1?0:100+Math.min(70,Math.floor((level-1)/40)*2),
  layout:(level-1)%6,
  tier
 };
}
export function initialProgress(){return {version:2,coins:0,unlocked:1,completed:{},totalEarned:0};}
export function normalizeProgress(value){
 const p=initialProgress();
 if(!value||typeof value!=='object')return p;
 const coins=Number(value.coins),unlocked=Number(value.unlocked);
 p.coins=Number.isSafeInteger(coins)&&coins>=0?Math.min(99999999,coins):0;
 p.unlocked=Number.isInteger(unlocked)?Math.max(1,Math.min(TOTAL_STAGES,unlocked)):1;
 if(value.completed&&typeof value.completed==='object'){
  for(const [key,v] of Object.entries(value.completed)){
   const level=Number(key);
   if(Number.isInteger(level)&&level>=1&&level<=p.unlocked&&String(level)===key)
    p.completed[key]=Math.min(3,Math.max(0,Math.floor(Number(v)||0)));
  }
 }
 p.totalEarned=Number.isSafeInteger(value.totalEarned)&&value.totalEarned>=0?value.totalEarned:0;
 return p;
}
/* Each mission's starting geometry differs. These are normal occupied cells, not
   impossible-to-remove blockers, so any completed row/column/box clears them. */
export function stageBoard(level){
 const cfg=stageConfig(level);
 const rng=seededRng(hashDate('nova-galaxy-geometry-'+level));
 const board=Array.from({length:9},()=>Array(9).fill(0));
 const add=(r,c)=>{if(r>=0&&c>=0&&r<9&&c<9)board[r][c]=1;};
 if(level===1)return board; // Gentle onboarding.
 const count=3+cfg.tier+(cfg.layout%3);
 if(cfg.kind==='rows'){
  const row=Math.floor(rng()*9);
  for(let i=0;i<Math.min(6,count+2);i++)add(row,(i*2+cfg.layout)%9);
 }else if(cfg.kind==='columns'){
  const col=Math.floor(rng()*9);
  for(let i=0;i<Math.min(6,count+2);i++)add((i*2+cfg.layout)%9,col);
 }else if(cfg.kind==='squares'){
  const y=Math.floor(rng()*3)*3,x=Math.floor(rng()*3)*3;
  for(let i=0;i<Math.min(6,count+2);i++)add(y+Math.floor(i/3),x+i%3);
 }else if(cfg.kind==='combo'){
  const row=Math.floor(rng()*9),col=Math.floor(rng()*9);
  for(let i=0;i<4;i++){add(row,(i*2)%9);add((i*2+1)%9,col);}
 }else if(cfg.kind==='survival'){
  for(let i=0;i<count;i++)add((i*2+cfg.layout)%9,(i*3+cfg.world)%9);
 }else if(cfg.kind==='clearing'){
  const row=Math.floor(rng()*9);
  for(let i=0;i<5;i++)add(row,(i+cfg.layout)%9);
 }else if(cfg.kind==='mastery'){
  const offset=Math.floor(rng()*3)*3;
  for(let i=0;i<5;i++)add(offset+Math.floor(i/3),offset+i%3);
 }else{
  for(let i=0;i<count;i++)add(Math.floor(rng()*9),Math.floor(rng()*9));
 }
 // A few extra deterministic occupied cells give higher worlds distinct board texture.
 for(let i=0;i<Math.floor(cfg.tier/2);i++)add(Math.floor(rng()*9),Math.floor(rng()*9));
 return board;
}
export function startStage(level){
 stageConfig(level);
 const date='nova-stage-'+level,game=makeGame('daily',date);
 const board=stageBoard(level);
 // Ensure starting tray is playable against the actual configured starting board.
 const tray=hasMove(board,game.tray)?game.tray:drawTray(seededRng(hashDate(date+'-tray')),board);
 return {...game,board,tray,mode:'stage',stageLevel:level,clears:0,
  rows:0,columns:0,squares:0,cellsCleared:0,maxCombo:0,clearingMoves:0,
  date,won:false,over:false};
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
  default:return 0;
 }
}
const OBJECTIVE_NAMES={
 en:{score:'Score',rows:'Rows cleared',columns:'Columns cleared',squares:'3×3 cleared',combo:'Best chain',survival:'Placements',clearing:'Blocks removed',mastery:'Groups cleared',finish:'Play until no shapes fit'},
 fr:{score:'Score',rows:'Lignes effacées',columns:'Colonnes effacées',squares:'Carrés 3×3',combo:'Meilleure série',survival:'Pièces posées',clearing:'Blocs effacés',mastery:'Groupes effacés',finish:'Jouez jusqu’à épuisement des coups'},
 ar:{score:'النقاط',rows:'صفوف ممسوحة',columns:'أعمدة ممسوحة',squares:'مربعات 3×3',combo:'أفضل سلسلة',survival:'قطع موضوعة',clearing:'مربعات ممسوحة',mastery:'مجموعات ممسوحة',finish:'كمّل حتى ما يبقى حتى حل'}
};
export function stageObjectiveText(state,lang='en'){
 const cfg=stageConfig(state.stageLevel),t=OBJECTIVE_NAMES[lang]||OBJECTIVE_NAMES.en;
 const base=t[cfg.kind]+' '+objectiveValue(state,cfg)+'/'+cfg.goal;
 return cfg.kind==='mastery'?base+' · '+t.score+' '+(state.score||0)+'/'+cfg.scoreBonus:base;
}
export function stageWon(state){
 if(state.mode!=='stage'||!state.over)return false; // Never finish when only the target has been reached.
 const cfg=stageConfig(state.stageLevel);
 if((state.moves||0)<cfg.minMoves)return false;
 return objectiveValue(state,cfg)>=cfg.goal && (cfg.kind!=='mastery'||state.score>=cfg.scoreBonus);
}
export function stageFailed(state){return state.mode==='stage'&&!!state.over&&!stageWon(state);}
export function rankStage(state){
 if(!stageWon(state))return 0;
 const cfg=stageConfig(state.stageLevel),ratio=objectiveValue(state,cfg)/cfg.goal;
 return ratio>=2.25&&state.score>=cfg.scoreBonus?3:ratio>=1.45?2:1;
}
export function awardStage(progress,level,finishedState){
 const p=normalizeProgress(progress);
 // Neither reaching a goal early nor passing a number of points is an award.
 // Only a completed, successful, exhausted-board run grants stars and currency.
 if(level>p.unlocked||finishedState?.stageLevel!==level||!stageWon(finishedState))return {progress:p,earned:0};
 const stars=rankStage(finishedState);
 const prev=p.completed[level]||0;
 if(stars<=prev)return {progress:p,earned:0};
 const earned=prev===0?150+25*stars:15*(stars-prev);
 p.completed[level]=stars;p.coins+=earned;p.totalEarned+=earned;
 return {progress:p,earned};
}
export function purchaseStage(progress,level){
 const p=normalizeProgress(progress);
 if(!Number.isInteger(level)||level<2||level>TOTAL_STAGES)return {progress:p,ok:false,reason:'invalid'};
 if(level<=p.unlocked)return {progress:p,ok:true,cost:0};
 if(level!==p.unlocked+1||!(p.completed[level-1]>0))return {progress:p,ok:false,reason:'progress'};
 const cost=stageConfig(level).unlockCost;
 if(p.coins<cost)return {progress:p,ok:false,reason:'coins',cost};
 p.coins-=cost;p.unlocked=level;return {progress:p,ok:true,cost};
}
export function progressSummary(progress){
 const p=normalizeProgress(progress);
 return {completed:Object.values(p.completed).filter(v=>v>0).length,
  stars:Object.values(p.completed).reduce((a,b)=>a+b,0),
  coins:p.coins,unlocked:p.unlocked};
}
