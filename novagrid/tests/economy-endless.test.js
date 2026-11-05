import test from 'node:test';import assert from 'node:assert/strict';
import {normalizeWallet,earnForClear,earnCoins,buyWithPoints,spendBooster,clearForShield,reviveWithHeart} from '../web/economy.js';
import {makeGame,emptyBoard,hasMove} from '../web/engine.js';
test('earned coins can be spent on heart and shield with no money products',()=>{
 const w=earnCoins(null,300);
 assert.deepEqual(normalizeWallet(w),{coins:300,heart:0,shield:0});
 const purchased=buyWithPoints(w,'heart');
 assert.equal(purchased.ok,true);assert.equal(purchased.wallet.heart,1);assert.equal(purchased.wallet.coins,180);
 assert.equal(buyWithPoints({coins:100},'shield').ok,false);
 assert.deepEqual(spendBooster(purchased.wallet,'heart').wallet,{coins:180,heart:0,shield:0});
 assert.equal(earnForClear({groups:0},1),0);
 assert.ok(earnForClear({groups:2},2)>earnForClear({groups:1},1));
});
test('shield clears cells without awarding score, and never edits its argument',()=>{
 const board=emptyBoard();for(let r=0;r<9;r++)board[r][r]=1;
 const out=clearForShield(board,6);assert.equal(board.flat().filter(Boolean).length,9);assert.equal(out.flat().filter(Boolean).length,3);
 assert.equal(clearForShield(emptyBoard()),null);
});
test('a heart revives only a finished classic round',()=>{
 const game=makeGame('classic');assert.equal(reviveWithHeart(game),null);
 const full=Array.from({length:9},()=>Array(9).fill(1));const dead={...game,board:full,tray:game.tray,over:true,score:123,moves:88};
 const revived=reviveWithHeart(dead);assert.ok(revived);assert.equal(revived.over,false);assert.equal(revived.score,123);
 assert.equal(revived.assisted,true);assert.equal(hasMove(revived.board,revived.tray),true);assert.equal(dead.board.flat().filter(Boolean).length,81);
});
