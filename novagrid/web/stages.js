/* NovaGrid Galaxies: 2,000 original, deterministic progression stages.
   All progress is local. No purchases, accounts, or online rewards. */
import {makeGame} from './engine.js';
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
export function stageConfig(level){
 if(!Number.isInteger(level)||level<1||level>TOTAL_STAGES)throw new RangeError('Invalid NovaGrid stage');
 return {
  level,world:Math.floor((level-1)/WORLD_SIZE),ordinal:(level-1)%WORLD_SIZE+1,
  target:42+Math.min(360,Math.floor(level/8)*2),
  movesLimit:22+Math.min(28,Math.floor(level/65)),
  requiredClears:level<15?0:Math.min(3,1+Math.floor(level/450)),
  unlockCost:level===1?0:100+Math.min(70,Math.floor((level-1)/40)*2)
 };
}
export function initialProgress(){return {version:1,coins:0,unlocked:1,completed:{},totalEarned:0};}
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
export function startStage(level){
 const cfg=stageConfig(level);
 const game=makeGame('daily','nova-stage-'+level);
 return {...game,mode:'stage',stageLevel:level,clears:0,date:'nova-stage-'+level,
  won:false,over:false};
}
export function stageWon(state){
 if(state.mode!=='stage')return false;
 const c=stageConfig(state.stageLevel);
 return state.score>=c.target&&state.clears>=c.requiredClears;
}
export function stageFailed(state){
 if(state.mode!=='stage')return false;
 const c=stageConfig(state.stageLevel);
 return !stageWon(state)&&(state.over||state.moves>=c.movesLimit);
}
export function rankStage(state){
 const c=stageConfig(state.stageLevel);
 if(!stageWon(state))return 0;
 const efficiency=state.moves/c.movesLimit;
 return efficiency<=.44?3:efficiency<=.74?2:1;
}
export function awardStage(progress,level,stars){
 const p=normalizeProgress(progress);
 if(level>p.unlocked||stars<1||stars>3||!Number.isInteger(stars))return {progress:p,earned:0};
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
 p.coins-=cost;p.unlocked=level;
 return {progress:p,ok:true,cost};
}
export function progressSummary(progress){
 const p=normalizeProgress(progress);
 return {completed:Object.values(p.completed).filter(v=>v>0).length,
  stars:Object.values(p.completed).reduce((a,b)=>a+b,0),
  coins:p.coins,unlocked:p.unlocked};
}
