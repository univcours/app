import test from 'node:test';
import assert from 'node:assert/strict';
import {emptyBoard,place,hasMove} from '../web/engine.js';
import {TOTAL_STAGES,SECTORS,stageConfig,startStage,stageWon,stageFailed,rankStage,
 awardStage,purchaseStage,isStageUnlocked,initialProgress,normalizeProgress,
 drawSectorTray,stageObjectiveText,applySectorTurn,progressSummary} from '../web/stages.js';

test('exactly three unique Candy Arcade stages, no 14,000 hidden stages',()=>{
 assert.equal(TOTAL_STAGES,3);assert.equal(SECTORS.length,3);
 assert.deepEqual([1,2,3].map(x=>stageConfig(x).kind),['candy','rocket','bomb']);
 assert.deepEqual([1,2,3].map(x=>stageConfig(x).scoreTarget),[260,800,1400]);
 for(const level of [0,4,12001,14000])assert.throws(()=>stageConfig(level),RangeError);
});
test('legacy 14k progress does not unlock the new handcrafted stages',()=>{
 const p=initialProgress();
 assert.equal(isStageUnlocked(p,1),true);
 assert.equal(isStageUnlocked(p,2),false);
 assert.equal(purchaseStage(p,2).ok,false);
 assert.deepEqual(normalizeProgress({version:3,unlocked:14000,coins:9999,completed:{1:3,2:3}}),p);
});
test('every stage starts deterministically with playable pieces',()=>{
 for(let level=1;level<=3;level++){
  const a=startStage(level),b=startStage(level);
  assert.deepEqual(a.board,b.board);assert.deepEqual(a.tray,b.tray);
  assert.equal(a.stageLevel,level);assert.ok(hasMove(a.board,a.tray));
  for(let round=0;round<15;round++){
   const x=drawSectorTray(level,a.board,round);
   assert.deepEqual(x,drawSectorTray(level,a.board,round));
   assert.ok(hasMove(a.board,x));
  }
 }
});
test('rocket actually clears board cells; two bombs defeat boss deterministically',()=>{
 const c=applySectorTurn({...startStage(1),moves:9},{groups:2});
 assert.equal(c.candyBursts,2);assert.equal(c.score,30);
 const first=startStage(2),r=applySectorTurn({...first,moves:9},{groups:1});
 assert.equal(r.rocketShots,1);assert.equal(r.specialEvent.kind,'rocket');
 assert.ok(r.board.flat().filter(Boolean).length<=first.board.flat().filter(Boolean).length);
 assert.deepEqual(r.board,applySectorTurn({...first,moves:9},{groups:1}).board);
 const one=applySectorTurn({...startStage(3),moves:11},{groups:1});
 assert.equal(one.bossHp,2);assert.equal(one.bombBlasts,1);
 assert.equal(one.specialEvent.cells.length,9);
 const two=applySectorTurn({...one,moves:12},{groups:1});
 assert.equal(two.bossHp,1);assert.equal(two.bombBlasts,2);
 const three=applySectorTurn({...two,moves:13},{groups:1});
 assert.equal(three.bossHp,0);assert.equal(three.bombBlasts,3);
});
test('score, actual specials and minimum moves all required for progression',()=>{
 let progress=initialProgress();
 for(const level of [1,2,3]){
  const c=stageConfig(level),s=startStage(level);
  s.moves=c.minMoves;s.score=c.scoreTarget;
  assert.equal(stageWon(s),false);
  s.clears=2;s.rocketShots=3;s.bombBlasts=3;s.bossHp=0;
  assert.equal(stageWon(s),true);assert.ok(rankStage(s)>=1);
  assert.ok(stageObjectiveText(s,'ar').length>4);
  assert.equal(awardStage(progress,level,{...s,over:true,won:false}).earned,0);
  assert.equal(awardStage(progress,level,{...s,over:false,won:true}).earned,0);
  const result=awardStage(progress,level,{...s,over:true,won:true});
  assert.ok(result.earned>=100);
  progress=result.progress;
  assert.equal(progress.unlocked,Math.min(3,level+1));
  assert.equal(awardStage(progress,level,{...s,over:true,won:true}).earned,0);
  assert.equal(stageWon({...s,score:c.scoreTarget-1}),false);
  assert.equal(stageWon({...s,moves:c.minMoves-1}),false);
  assert.equal(stageFailed({...s,score:0,over:true}),true);
 }
 assert.equal(progressSummary(progress).completed,3);
 assert.equal(isStageUnlocked(progress,4),false);
});
test('row and square clears stay correct in the original puzzle engine',()=>{
 const b=emptyBoard();for(let i=0;i<8;i++)b[0][i]=1;
 assert.equal(place(b,[[0,0]],0,8).rows,1);
 const sq=emptyBoard();for(let r=3;r<6;r++)for(let c=3;c<6;c++)sq[r][c]=1;
 sq[5][5]=0;assert.equal(place(sq,[[0,0]],5,5).squares,1);
});
