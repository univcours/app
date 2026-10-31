import test from 'node:test';
import assert from 'node:assert/strict';
import {place,emptyBoard,hasMove} from '../web/engine.js';
import {WORLD_SIZE,SECTOR_SIZE,TOTAL_STAGES,TOTAL_WORLDS,SECTORS,WORLD_NAMES,
 stageConfig,stageBoard,startStage,stageWon,stageFailed,rankStage,objectiveValue,
 stageObjectiveText,awardStage,purchaseStage,isStageUnlocked,initialProgress,
 normalizeProgress,progressSummary,collapseBoard,applySectorTurn,drawSectorTray} from '../web/stages.js';

test('12,000 levels: six sections, twenty worlds each',()=>{
 assert.equal(TOTAL_STAGES,12000);assert.equal(TOTAL_WORLDS,120);
 assert.equal(WORLD_SIZE,100);assert.equal(SECTOR_SIZE,2000);
 assert.equal(SECTORS.length,6);assert.equal(WORLD_NAMES.length,120);
 for(let sector=0;sector<6;sector++){
  const first=sector*2000+1,config=stageConfig(first);
  assert.equal(config.sector,sector);assert.equal(config.world,sector*20);
  assert.equal(stageConfig(first+1999).sector,sector);
  assert.ok(config.goal>0);
 }
 assert.equal(stageConfig(2001).sectorId,'meteor');
 assert.equal(stageConfig(4001).gravity,true);
 assert.equal(stageConfig(6001).sectorId,'prism');
 assert.equal(stageConfig(8001).sectorId,'reactor');
 assert.equal(stageConfig(10001).sectorId,'void');
 assert.throws(()=>stageConfig(12001),RangeError);
});
test('all six sections have a free entry stage and sequential earned-points progression',()=>{
 const p=initialProgress();
 for(let sec=0;sec<6;sec++){
  const first=sec*2000+1;assert.equal(isStageUnlocked(p,first),true);
  assert.equal(isStageUnlocked(p,first+1),false);
 }
 const first=2001,config=stageConfig(first),s=startStage(first);
 const keys={score:'score',rows:'rows',columns:'columns',squares:'squares',
  combo:'maxCombo',survival:'moves',clearing:'cellsCleared',mastery:'clears',charge:'charge'};
 s.moves=config.minMoves;s.score=10000;s[keys[config.kind]]=Math.max(config.goal,s[keys[config.kind]]||0);s.over=true;
 const earned=awardStage(p,first,s);
 assert.ok(earned.earned>=175);
 assert.equal(purchaseStage(earned.progress,first+1).ok,true);
 assert.equal(purchaseStage(p,first+1).reason,'progress');
 assert.equal(purchaseStage(earned.progress,first+2).reason,'progress');
 assert.equal(awardStage(earned.progress,first,s).earned,0);
});
test('previous two-thousand level saves survive normalization',()=>{
 const p=normalizeProgress({version:2,coins:500,unlocked:120,completed:{'1':3,'110':1},totalEarned:660});
 assert.equal(p.unlocked,120);assert.equal(p.unlockedSectors[0],120);
 assert.equal(p.completed[1],3);assert.equal(p.completed[110],1);
 assert.equal(p.coins,500);assert.equal(p.unlockedSectors[1],2001);
 assert.equal(progressSummary(p).completed,2);
 assert.equal(normalizeProgress({coins:-15,unlocked:99999}).unlocked,2000);
});
test('each campaign begins with playable deterministic puzzles',()=>{
 for(const level of [1,2,3,8,99,1200,1999,2000,2001,2200,3999,4001,6001,8001,10001,12000]){
  const a=startStage(level),b=startStage(level);
  assert.deepEqual(a.board,b.board);assert.deepEqual(a.tray,b.tray);
  assert.equal(a.stageLevel,level);assert.equal(a.over,false);
  assert.equal(hasMove(a.board,a.tray),true,'stage '+level);
  assert.deepEqual(a.board,stageBoard(level));
 }
});
test('gravity pulls cells down without creating or destroying any',()=>{
 const b=emptyBoard();b[0][0]=1;b[4][0]=1;b[2][4]=1;
 const g=collapseBoard(b);assert.equal(g[8][0],1);assert.equal(g[7][0],1);
 assert.equal(g[8][4],1);assert.equal(g[0][0],0);
 assert.equal(g.flat().filter(Boolean).length,3);assert.equal(b[0][0],1);
});
test('meteor pattern is deterministic and different from ordinary game',()=>{
 const s=startStage(2001);
 const a=applySectorTurn({...s,moves:3},{groups:0,squares:0});
 const b=applySectorTurn({...s,moves:3},{groups:0,squares:0});
 assert.deepEqual(a.board,b.board);assert.equal(a.meteorHits,1);
 assert.ok(a.board.flat().filter(Boolean).length>s.board.flat().filter(Boolean).length);
 const gravity=startStage(4001),g=applySectorTurn({...gravity,moves:1},{groups:0,squares:0});
 assert.deepEqual(g.board,collapseBoard(gravity.board));
});
test('prism and reactor use separate bonuses and charge meters',()=>{
 const s=startStage(6001),p=applySectorTurn({...s,moves:1},{groups:1,squares:2});
 assert.equal(p.charge,2);assert.ok(p.score>=50);
 const r=startStage(8001),c=applySectorTurn({...r,moves:1,combo:2},{groups:1,squares:0});
 assert.equal(c.charge,1);assert.ok(c.score>=12);
});
test('mission rewards require completion of real puzzle, not only crossing threshold',()=>{
 const keys={score:'score',rows:'rows',columns:'columns',squares:'squares',
  combo:'maxCombo',survival:'moves',clearing:'cellsCleared',mastery:'clears',charge:'charge'};
 for(const level of [1,2,3,4,5,6,7,8,6002,8002]){
  const config=stageConfig(level),s=startStage(level);
  s.moves=config.minMoves;s.score=10000;s[keys[config.kind]]=Math.max(config.goal,s[keys[config.kind]]||0);
  assert.equal(stageWon(s),false);assert.equal(awardStage(initialProgress(),level,s).earned,0);
  s.over=true;assert.equal(stageWon(s),true,config.kind+' level '+level);
  assert.ok(rankStage(s)>=1);assert.ok(stageObjectiveText(s,'ar').length>4);
  s[keys[config.kind]]=0;assert.equal(stageWon(s),false);
  assert.equal(stageFailed(s),true);
 }
});
test('core engine distinguishes row and square clear events',()=>{
 const b=emptyBoard();for(let c=0;c<8;c++)b[0][c]=1;
 assert.equal(place(b,[[0,0]],0,8).rows,1);
 const sq=emptyBoard();for(let r=3;r<6;r++)for(let c=3;c<6;c++)sq[r][c]=1;
 sq[5][5]=0;assert.equal(place(sq,[[0,0]],5,5).squares,1);
});

test('sector shape selection is reproducible and always playable',()=>{
 for(const level of [2001,4001,6001,8001,10001,12000]){
  const state=startStage(level);
  const first=drawSectorTray(level,state.board,0);
  const again=drawSectorTray(level,state.board,0);
  assert.deepEqual(first,again);
  assert.equal(hasMove(state.board,first),true);
  const newTray=drawSectorTray(level,state.board,1);
  assert.equal(newTray.length,3);
  assert.ok(newTray.every(piece=>piece.length>=1));
 }
});
test('all twelve thousand stage configurations remain valid and every hundredth starts playable',()=>{
 const types=new Set(),sections=new Set();
 for(let level=1;level<=TOTAL_STAGES;level++){
  const cfg=stageConfig(level);
  assert.equal(cfg.level,level);assert.ok(Number.isFinite(cfg.goal)&&cfg.goal>0);
  assert.ok(cfg.sector>=0&&cfg.sector<6);
  assert.ok(cfg.world>=0&&cfg.world<120);
  assert.ok(cfg.minMoves>=6&&cfg.unlockCost>=0);
  types.add(cfg.kind);sections.add(cfg.sectorId);
  if(level===1||level%100===0){
   const s=startStage(level);
   assert.equal(s.board.length,9);assert.equal(s.tray.length,3);
   assert.equal(hasMove(s.board,s.tray),true,'stage '+level+' must have a move');
  }
 }
 assert.ok(types.size>=9);assert.equal(sections.size,6);
});
