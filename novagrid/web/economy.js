import {drawTray,seededRng,hasMove} from './engine.js';
/* Points-only economy. No money checkout or paid advantage in public leaderboards. */
export const OFFERS=Object.freeze([
 Object.freeze({id:'heart',label:'❤️',cost:120}),
 Object.freeze({id:'shield',label:'🛡️',cost:160})
]);
export function normalizeWallet(value){
 const n=x=>Number.isSafeInteger(x)?Math.min(1000000,Math.max(0,x)):0;
 return {coins:n(value?.coins),heart:Math.min(99,n(value?.heart)),shield:Math.min(99,n(value?.shield))};
}
export function earnForClear(result,combo){
 return result?.groups>0?Math.min(100,8*result.groups+Math.max(0,combo-1)*3):0;
}
export function earnCoins(wallet,amount){
 const w=normalizeWallet(wallet);
 if(!Number.isSafeInteger(amount)||amount<=0)return w;
 return {...w,coins:Math.min(1000000,w.coins+amount)};
}
export function buyWithPoints(wallet,itemId){
 const w=normalizeWallet(wallet),offer=OFFERS.find(x=>x.id===itemId);
 if(!offer||w.coins<offer.cost||w[offer.id]>=99)return {ok:false,wallet:w};
 return {ok:true,wallet:{...w,coins:w.coins-offer.cost,[offer.id]:w[offer.id]+1}};
}
export function spendBooster(wallet,itemId){
 const w=normalizeWallet(wallet);
 if(!['heart','shield'].includes(itemId)||w[itemId]<1)return {ok:false,wallet:w};
 return {ok:true,wallet:{...w,[itemId]:w[itemId]-1}};
}
export function clearForShield(board,limit=6){
 if(!Array.isArray(board)||board.length!==9||!board.every(row=>Array.isArray(row)&&row.length===9))return null;
 const next=board.map(row=>[...row]),filled=[];
 for(let r=0;r<9;r++)for(let c=0;c<9;c++)if(next[r][c])filled.push([r,c]);
 if(!filled.length)return null;
 filled.sort((a,b)=>Math.abs(a[0]-4)+Math.abs(a[1]-4)-Math.abs(b[0]-4)-Math.abs(b[1]-4));
 for(const [r,c] of filled.slice(0,Math.max(1,Math.min(18,limit))))next[r][c]=0;
 return next;
}

/* A heart gives a genuine last chance; it does not reset the score or bypass scoring. */
export function reviveWithHeart(state){
 if(!state||state.mode!=='classic'||!state.over||!Array.isArray(state.board))return null;
 let board=clearForShield(state.board,18);
 if(!board)board=state.board.map(row=>row.slice());
 let rng=seededRng(((state.seed||1234567)^(Math.imul((state.moves||0)+1,2654435761)))>>>0);
 let tray=drawTray(rng,board,state.moves||0);
 if(!hasMove(board,tray)){
  board=board.map(row=>row.map(()=>0));
  tray=drawTray(rng,board,state.moves||0);
 }
 return {...state,board,tray,combo:0,over:false,assisted:true,fever:{meter:0,activeMoves:0}};
}
