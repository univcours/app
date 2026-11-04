/* NovaGrid: three hand-crafted Candy Arcade stages. Add more only after QA.
   Local progress is isolated from the retired 14,000-stage Galaxy save. */
import {makeGame,seededRng,hashDate,hasMove,drawTray,anyPlacement,PATTERNS} from './engine.js';

export const TOTAL_STAGES=3;
export const WORLD_SIZE=1;
export const WORLDS_PER_SECTOR=1;
export const SECTOR_SIZE=1;
export const TOTAL_WORLDS=3;
export const SECTORS=Object.freeze([
 {id:'candy',icon:'🍬',name:{en:'Candy Pop',fr:'Candy Pop',ar:'انفجار الحلوى'},
  philosophy:{en:'Clear two lines or boxes and reach 260 points',fr:'Effacez 2 lignes ou carrés et marquez 260 points',ar:'مسح جوج صفوف أو مربعات ووصل لـ260 نقطة'}},
 {id:'rocket',icon:'🚀',name:{en:'Rocket Rush',fr:'Course aux fusées',ar:'سباق الصواريخ'},
  philosophy:{en:'Trigger two rockets and reach 450 points',fr:'Lancez 2 fusées et marquez 450 points',ar:'طلّق جوج صواريخ ووصل لـ450 نقطة'}},
 {id:'bomb',icon:'💣',name:{en:'Candy Bomb Boss',fr:'Boss bombes',ar:'زعيم القنابل'},
  philosophy:{en:'Detonate two bombs and reach 700 points',fr:'Explosez 2 bombes et marquez 700 points',ar:'فجّر جوج قنابل ووصل لـ700 نقطة'}}
]);
export const WORLD_NAMES=SECTORS.map(s=>s.name.en);
export const WORLD_SYMBOLS=SECTORS.map(s=>s.icon);
export const MISSION_TYPES=['candy','rocket','bomb'];

export function stageConfig(level){
 if(!Number.isInteger(level)||level<1||level>TOTAL_STAGES)throw new RangeError('Only three NovaGrid Candy Arcade stages exist');
 const i=level-1,goals=[260,450,700],requirements=[2,2,2],moves=[6,8,10];
 return {
  level,world:i,sector:i,sectorId:SECTORS[i].id,sectorName:SECTORS[i].name,ordinal:1,
  kind:MISSION_TYPES[i],goal:goals[i],target:goals[i],scoreTarget:goals[i],
  specialTarget:requirements[i],minMoves:moves[i],
  unlockCost:0,tier:i,layout:i,hazardEvery:0,gravity:false,boss:level===3,
  bossHp:level===3?2:0
 };
}
export function initialProgress(){return {version:4,coins:0,unlocked:1,completed:{},totalEarned:0};}
export function normalizeProgress(value){
 const p=initialProgress();
 if(!value||typeof value!=='object')return p;
 // Only native version-4 Candy Arcade saves are eligible. Legacy saves
 // from the previous Galaxy are never mistaken for wins in these new stages.
 if(value.version!==4)return p;
 const coins=Number(value.coins);
 if(Number.isSafeInteger(coins)&&coins>=0)p.coins=Math.min(99999999,coins);
 if(value.completed&&typeof value.completed==='object'){
  for(let level=1;level<=TOTAL_STAGES;level++){
   const stars=Number(value.completed[level]);
   if(Number.isInteger(stars)&&stars>=1&&stars<=3&&
      (level===1||p.completed[level-1]))p.completed[level]=stars;
  }
 }
 for(let level=1;level<TOTAL_STAGES&&p.completed[level];level++)p.unlocked=level+1;
 const earned=Number(value.totalEarned);
 if(Number.isSafeInteger(earned)&&earned>=0)p.totalEarned=earned;
 return p;
}
export function isStageUnlocked(progress,level){
 if(!Number.isInteger(level)||level<1||level>TOTAL_STAGES)return false;
 return level<=normalizeProgress(progress).unlocked;
}
export function stageBoard(level){
 stageConfig(level);
 const b=Array.from({length:9},()=>Array(9).fill(0));
 if(level===2){for(let c=0;c<5;c++)b[4][c]=1;}
 if(level===3){for(let c=0;c<6;c++)b[2][c]=1;for(let r=5;r<8;r++)b[r][7]=1;}
 return b;
}
export function drawSectorTray(level,board,round=0){
 stageConfig(level);
 const rng=seededRng(hashDate('nova-candy-tray-'+level+'-'+round));
 const choices=PATTERNS.filter(p=>level===1?p.length<=6:level===2?p.length>=2&&p.length<=6:p.length>=2&&p.length<=7);
 const tray=Array.from({length:3},()=>choices[Math.floor(rng()*choices.length)].map(x=>[...x]));
 if(!hasMove(board,tray)){
  const playable=PATTERNS.filter(p=>anyPlacement(board,p));
  if(playable.length)tray[0]=playable[Math.floor(rng()*playable.length)].map(x=>[...x]);
 }
 return tray;
}
export function startStage(level){
 const cfg=stageConfig(level),date='nova-candy-stage-'+level,game=makeGame('daily',date);
 const board=stageBoard(level);
 const tray=drawSectorTray(level,board,0);
 return {...game,mode:'stage',date,stageLevel:level,sectorId:cfg.sectorId,
  board,tray,score:0,moves:0,combo:0,over:false,won:false,
  clears:0,rows:0,columns:0,squares:0,cellsCleared:0,
  clearingMoves:0,maxCombo:0,charge:0,rocketShots:0,bombBlasts:0,
  candyBursts:0,bossHp:cfg.bossHp,specialEvent:null};
}
function bestBlast(board,kind,moves){
 const candidates=[];
 if(kind==='rocket'){
  for(let r=0;r<9;r++)candidates.push({direction:'row',index:r,cells:Array.from({length:9},(_,c)=>[r,c])});
  for(let c=0;c<9;c++)candidates.push({direction:'column',index:c,cells:Array.from({length:9},(_,r)=>[r,c])});
 }else{
  for(let r=1;r<8;r++)for(let c=1;c<8;c++){
   const cells=[];for(let y=r-1;y<=r+1;y++)for(let x=c-1;x<=c+1;x++)cells.push([y,x]);
   candidates.push({direction:'blast',index:r*9+c,cells,center:[r,c]});
  }
 }
 const score=x=>x.cells.filter(([r,c])=>board[r][c]).length;
 candidates.sort((a,b)=>score(b)-score(a)||Math.abs(a.index-moves%9)-Math.abs(b.index-moves%9)||a.index-b.index);
 const chosen=candidates[0],next=board.map(row=>row.slice());
 let removed=0;
 for(const [r,c] of chosen.cells)if(next[r][c]){next[r][c]=0;removed++;}
 return {board:next,removed,center:chosen.center||(
  chosen.direction==='row'?[chosen.index,4]:[4,chosen.index]),
  cells:chosen.cells,direction:chosen.direction};
}
export function applySectorTurn(state,result){
 if(state.mode!=='stage')return state;
 const cfg=stageConfig(state.stageLevel),next={...state,specialEvent:null};
 if(!result?.groups){
  next.over=!!state.over||!hasMove(next.board,next.tray);
  return next;
 }
 next.charge=(state.charge||0)+result.groups;
 if(cfg.kind==='candy'){
  next.candyBursts=(state.candyBursts||0)+result.groups;
  next.score+=15*result.groups;
  next.specialEvent={kind:'candy',center:[4,4],cells:[],removed:0};
 }else{
  const kind=cfg.kind,blast=bestBlast(next.board,kind,next.moves);
  next.board=blast.board;
  const bonus=(kind==='rocket'?40:60)+blast.removed*12;
  next.score+=bonus;
  next.cellsCleared=(state.cellsCleared||0)+blast.removed;
  if(kind==='rocket')next.rocketShots=(state.rocketShots||0)+1;
  if(kind==='bomb'){
   next.bombBlasts=(state.bombBlasts||0)+1;
   next.bossHp=Math.max(0,(state.bossHp??cfg.bossHp)-1);
  }
  next.specialEvent={kind,center:blast.center,cells:blast.cells,removed:blast.removed,direction:blast.direction,bonus};
 }
 next.over=!hasMove(next.board,next.tray);
 return next;
}
export function objectiveValue(state,cfg=stageConfig(state.stageLevel)){
 if(cfg.kind==='rocket')return state.rocketShots||0;
 if(cfg.kind==='bomb')return state.bombBlasts||0;
 return state.clears||0;
}
export function stageObjectiveText(state,lang='en'){
 const cfg=stageConfig(state.stageLevel);
 const labels={
  en:['Candy clears','Rockets fired','Bombs exploded','Score'],
  fr:['Éliminations Candy','Fusées tirées','Bombes explosées','Score'],
  ar:['مسح الحلوى','الصواريخ','القنابل','النقاط']
 };
 const t=labels[lang]||labels.en;
 return t[cfg.level-1]+' '+objectiveValue(state,cfg)+'/'+cfg.specialTarget+
  ' · '+t[3]+' '+(state.score||0)+'/'+cfg.scoreTarget;
}
export function stageWon(state){
 if(state?.mode!=='stage')return false;
 const cfg=stageConfig(state.stageLevel);
 return (state.moves||0)>=cfg.minMoves&&(state.score||0)>=cfg.scoreTarget&&
   objectiveValue(state,cfg)>=cfg.specialTarget&&(!cfg.boss||(state.bossHp??cfg.bossHp)===0);
}
export function stageFailed(state){return state?.mode==='stage'&&!!state.over&&!stageWon(state);}
export function rankStage(state){
 if(!stageWon(state))return 0;
 const cfg=stageConfig(state.stageLevel);
 const bonus=(state.score||0)/cfg.scoreTarget;
 return bonus>=1.6&&(state.maxCombo||0)>=3?3:bonus>=1.25||(state.maxCombo||0)>=2?2:1;
}
export function awardStage(progress,level,finished){
 const p=normalizeProgress(progress);
 if(!isStageUnlocked(p,level)||finished?.stageLevel!==level||
   !finished?.over||!finished?.won||!stageWon(finished))return {progress:p,earned:0};
 const stars=rankStage(finished),prior=p.completed[level]||0;
 if(stars<=prior)return {progress:p,earned:0};
 const earned=prior===0?100+stars*35:15*(stars-prior);
 p.completed[level]=stars;p.coins+=earned;p.totalEarned+=earned;
 if(level<TOTAL_STAGES)p.unlocked=Math.max(p.unlocked,level+1);
 return {progress:p,earned};
}
export function purchaseStage(progress,level){
 const p=normalizeProgress(progress);
 if(!Number.isInteger(level)||level<1||level>TOTAL_STAGES)return {progress:p,ok:false,reason:'invalid'};
 if(isStageUnlocked(p,level))return {progress:p,ok:true,cost:0};
 if(level!==p.unlocked+1||!p.completed[level-1])return {progress:p,ok:false,reason:'progress'};
 p.unlocked=level;
 return {progress:p,ok:true,cost:0};
}
export function progressSummary(progress){
 const p=normalizeProgress(progress);
 return {completed:Object.values(p.completed).filter(v=>v>0).length,
  stars:Object.values(p.completed).reduce((a,b)=>a+b,0),coins:p.coins,
  unlocked:p.unlocked,unlockedSectors:[p.unlocked]};
}
// Legacy exports kept for harmless test and plugin interoperability.
export function collapseBoard(board){return board.map(row=>row.slice());}
