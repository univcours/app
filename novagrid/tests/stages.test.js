import test from 'node:test';import assert from 'node:assert/strict';
import {WORLD_SIZE,TOTAL_STAGES,TOTAL_WORLDS,WORLD_NAMES,stageConfig,startStage,stageWon,
 stageFailed,rankStage,awardStage,purchaseStage,initialProgress,normalizeProgress,progressSummary} from '../web/stages.js';
test('the NovaGrid galaxy offers two thousand numbered stages in twenty worlds',()=>{
 assert.equal(TOTAL_WORLDS*WORLD_SIZE,2000);
 assert.equal(TOTAL_STAGES,2000);assert.equal(WORLD_NAMES.length,20);
 for(let i=1;i<=TOTAL_STAGES;i++){const s=stageConfig(i);assert.equal(s.level,i);
  assert.equal(s.world,Math.floor((i-1)/100));assert.ok(s.movesLimit>=22&&s.target>=42);}
 assert.equal(stageConfig(2000).ordinal,100);
 assert.throws(()=>stageConfig(2001),RangeError);
});
test('stage replay is deterministic and compatible with block puzzle engine',()=>{
 const a=startStage(99),b=startStage(99);
 assert.deepEqual(a.tray,b.tray);assert.equal(a.mode,'stage');assert.equal(a.stageLevel,99);
});
test('first stage is free, earning stars gives Nova Points to purchase second stage',()=>{
 const p=initialProgress();
 assert.equal(p.unlocked,1);assert.equal(p.coins,0);
 assert.equal(purchaseStage(p,2).ok,false);
 const winner=awardStage(p,1,2);
 assert.equal(winner.earned,200);
 assert.equal(winner.progress.coins,200);
 assert.equal(p.coins,0); // immutable
 const purchased=purchaseStage(winner.progress,2);
 assert.equal(purchased.ok,true);assert.equal(purchased.cost,100);
 assert.equal(purchased.progress.unlocked,2);
 assert.equal(purchased.progress.coins,100);
 assert.equal(purchased.progress.completed[1],2);
});
test('stages unlock sequentially, cannot purchase future levels or farm repeatedly',()=>{
 const p=awardStage(initialProgress(),1,3).progress;
 assert.equal(purchaseStage(p,3).ok,false);
 assert.equal(awardStage(p,1,3).earned,0);
 const bought=purchaseStage(p,2).progress;
 assert.equal(purchaseStage(bought,2).cost,0);
 assert.equal(purchaseStage(bought,3).ok,false);
 assert.equal(awardStage(p,2,3).earned,0);
});
test('success requires score and clears, failures use the move limit',()=>{
 const a=startStage(2),c=stageConfig(2);
 a.score=c.target;a.moves=2;
 assert.equal(stageWon(a),true);assert.equal(rankStage(a),3);
 const b=startStage(600),cfg=stageConfig(600);
 b.score=cfg.target;b.moves=cfg.movesLimit;b.clears=0;
 assert.equal(stageWon(b),false);assert.equal(stageFailed(b),true);
 b.clears=cfg.requiredClears;
 assert.equal(stageWon(b),true);assert.equal(stageFailed(b),false);
});
test('progress sanitization caps untrusted values and shows earned totals',()=>{
 const p=normalizeProgress({coins:-900,unlocked:5000,completed:{"1":3,"99999":3},totalEarned:-1});
 assert.equal(p.coins,0);assert.equal(p.unlocked,2000);assert.equal(p.completed[1],3);
 assert.equal(p.completed[99999],undefined);
 assert.equal(progressSummary(p).stars,3);
});
