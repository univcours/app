import test from 'node:test';
import assert from 'node:assert/strict';
import {canPlace,runMove,hasMove,place,emptyBoard} from '../web/engine.js';
import {WORLD_SIZE,TOTAL_STAGES,TOTAL_WORLDS,WORLD_NAMES,MISSION_TYPES,stageConfig,stageBoard,startStage,
 stageWon,stageFailed,rankStage,objectiveValue,stageObjectiveText,awardStage,purchaseStage,
 initialProgress,normalizeProgress,progressSummary} from '../web/stages.js';

test('2,000 stages across 20 themed worlds and eight rotating goal philosophies',()=>{
 assert.equal(TOTAL_WORLDS*WORLD_SIZE,2000);assert.equal(TOTAL_STAGES,2000);
 assert.equal(WORLD_NAMES.length,20);assert.equal(new Set(MISSION_TYPES).size,8);
 const goals=new Set();
 for(let i=1;i<=TOTAL_STAGES;i++){
  const config=stageConfig(i);
  assert.equal(config.world,Math.floor((i-1)/WORLD_SIZE));
  assert.ok(config.minMoves>=6&&config.goal>0);
  goals.add(config.kind);
 }
 assert.equal(goals.size,8);
 assert.equal(stageConfig(2000).ordinal,100);
 assert.throws(()=>stageConfig(2001),RangeError);
});

test('stage seed, starting geometry and tray repeat deterministically',()=>{
 for(const level of [1,2,3,4,5,6,7,8,99,125,500,1337,2000]){
  const a=startStage(level),b=startStage(level);
  assert.deepEqual(a.board,b.board);assert.deepEqual(a.tray,b.tray);
  assert.equal(a.mode,'stage');assert.equal(a.stageLevel,level);
  assert.equal(a.over,false);
  assert.ok(hasMove(a.board,a.tray));
  assert.deepEqual(a.board,stageBoard(level));
 }
 assert.deepEqual(startStage(1).board,emptyBoard());
 assert.notDeepEqual(startStage(2).board,startStage(3).board);
});

test('mission is NEVER won after two placements even if target is surpassed',()=>{
 const a=startStage(1),config=stageConfig(1);
 a.moves=2;a.score=10000;
 assert.equal(stageWon(a),false);
 assert.equal(stageFailed(a),false);
 assert.equal(rankStage(a),0);
 let award=awardStage(initialProgress(),1,a);
 assert.equal(award.earned,0);
 assert.equal(award.progress.completed[1],undefined);
 assert.equal(purchaseStage(award.progress,2).ok,false);
 a.over=true; // Board exhausted prematurely: unmet minimum gameplay, must retry.
 assert.equal(stageWon(a),false);
 assert.equal(stageFailed(a),true);
});

test('only genuine stage-end success grants stars and currency',()=>{
 const a=startStage(1),config=stageConfig(1);
 a.score=config.goal;a.moves=config.minMoves;
 assert.equal(stageWon(a),false);
 assert.equal(awardStage(initialProgress(),1,a).earned,0);
 a.over=true;
 assert.equal(stageWon(a),true);assert.equal(stageFailed(a),false);
 const reward=awardStage(initialProgress(),1,a);
 assert.equal(reward.earned,175);
 assert.equal(reward.progress.coins,175);
 assert.equal(reward.progress.completed[1],1);
 assert.equal(awardStage(reward.progress,1,a).earned,0);
 const bought=purchaseStage(reward.progress,2);
 assert.equal(bought.ok,true);
 assert.equal(bought.progress.unlocked,2);
 assert.equal(bought.progress.coins,75);
 assert.equal(purchaseStage(reward.progress,3).ok,false);
});

test('each objective demands its own separate metric and the board to be exhausted',()=>{
 const keys={score:'score',rows:'rows',columns:'columns',squares:'squares',
  combo:'maxCombo',survival:'moves',clearing:'cellsCleared',mastery:'clears'};
 for(let i=1;i<=8;i++){
  const config=stageConfig(i),s=startStage(i),key=keys[config.kind];
  s.moves=config.minMoves;s.score=9999;s.over=false;
  s[key]=config.goal;
  assert.equal(objectiveValue(s),config.goal);
  assert.equal(stageWon(s),false);
  s.over=true;assert.equal(stageWon(s),true,config.kind);
  s[key]=0;assert.equal(stageWon(s),false,config.kind);
  assert.equal(stageFailed(s),true);
  assert.ok(stageObjectiveText(s,'ar').length>5);
 }
});

test('objective progress reports actual row, column, and 3x3 clears',()=>{
 const b=emptyBoard();
 for(let c=0;c<8;c++)b[0][c]=1;
 const r=place(b,[[0,0]],0,8);
 assert.equal(r.rows,1);assert.equal(r.columns,0);assert.equal(r.squares,0);
 const b2=emptyBoard();
 for(let x=3;x<6;x++)for(let y=3;y<6;y++)b2[x][y]=1;
 b2[5][5]=0;
 const square=place(b2,[[0,0]],5,5);
 assert.equal(square.squares,1);
});

test('even after all goal conditions are met, runMove keeps puzzle playing until no moves',()=>{
 let s=startStage(1),count=0;
 for(let k=0;k<1000&&!s.over;k++){
  let move=null;
  for(let j=0;j<s.tray.length&&!move;j++)if(s.tray[j]){
   for(let row=0;row<9&&!move;row++)for(let col=0;col<9&&!move;col++){
    if(canPlace(s.board,s.tray[j],row,col))move=[j,row,col];
   }
  }
  assert.ok(move,'engine had moves but no placement');
  const result=runMove(s,...move);
  assert.ok(result);
  s=result.state;count++;
  if(!s.over){
   assert.equal(stageWon(s),false);
   assert.equal(stageFailed(s),false);
  }
 }
 assert.ok(count>2,'stage must not end trivially');
 assert.equal(s.over,true);
 assert.equal(hasMove(s.board,s.tray),false);
});

test('progress is sanitized, unlocks sequential, and stage failure never unlocks next',()=>{
 const p=normalizeProgress({coins:-900,unlocked:5000,completed:{'1':3,'99999':3},totalEarned:-1});
 assert.equal(p.coins,0);assert.equal(p.unlocked,2000);assert.equal(p.completed[1],3);
 assert.equal(p.completed[99999],undefined);
 assert.equal(progressSummary(p).stars,3);
 const failure=startStage(1);failure.over=true;failure.score=0;
 const declined=awardStage(initialProgress(),1,failure);
 assert.equal(declined.earned,0);
 assert.equal(purchaseStage(declined.progress,2).reason,'progress');
});
