import test from 'node:test';import assert from 'node:assert/strict';
import {FALL_WIDTH,FALL_HEIGHT,FALL_TYPES,emptyFallBoard,makeFallingState,canFallAt,rotateShape,
shuffledBag,pieceAt,tryMoveFalling,tryRotateFalling,clearFallLines,projectedRow,stepFalling,
hardDropFalling,fallingConfig,fallingWon,fallingStars,renderFallCells} from '../web/falling.js';
import {TOTAL_STAGES,initialProgress,awardStage,purchaseStage} from '../web/stages.js';
test('seven tetrominoes use one of each shape in each repeatable bag',()=>{
 for(let i=0;i<4;i++){const bag=shuffledBag(12001,i);assert.deepEqual([...bag].sort(),[...FALL_TYPES].sort());for(let j=0;j<7;j++)assert.equal(pieceAt(12001,i*7+j),bag[j]);}
});
test('rotation produces valid block coordinates and four rotations preserve shape',()=>{
 const square=[[0,0],[0,1],[1,0],[1,1]];
 assert.deepEqual(rotateShape(square).slice().sort().join('|'),square.slice().sort().join('|'));
 const right=rotateShape([[0,0],[0,1],[0,2],[0,3]]);
 assert.equal(right.length,4);assert.equal(new Set(right.map(([r,c])=>r)).size,4);
});
test('falling piece collides with floor and board boundaries',()=>{
 const b=emptyFallBoard();
 assert.equal(b.length,FALL_HEIGHT);assert.equal(b[0].length,FALL_WIDTH);
 assert.equal(canFallAt(b,[[0,0]],FALL_HEIGHT,0),false);
 assert.equal(canFallAt(b,[[0,0]],0,-1),false);
 b[5][4]='I';assert.equal(canFallAt(b,[[0,0]],5,4),false);
});
test('hard drop locks blocks, spawns a new shape and increments placements',()=>{
 const config=fallingConfig(12001),a=makeFallingState(12001),b=hardDropFalling(a,config);
 assert.equal(b.drops,1);assert.ok(b.board.flat().filter(Boolean).length===4);
 assert.ok(b.active);assert.equal(a.drops,0);assert.equal(b.won,false);
});
test('gravity moves one row at a time, wall collision is rejected',()=>{
 const cfg=fallingConfig(12002),s=makeFallingState(12002);
 const moved=stepFalling(s,cfg);
 assert.equal(moved.active.row,1);assert.equal(s.active.row,0);
 let edge={...s,active:{...s.active,col:0}};
 for(let i=0;i<20;i++)edge=tryMoveFalling(edge,-1);
 assert.ok(edge.active.col>=0);
 assert.ok(tryRotateFalling(edge).active.cells.length===4);
});
test('complete lines vanish, remaining contents fall downward',()=>{
 const b=emptyFallBoard();b[17].fill('I');b[16][0]='L';
 const out=clearFallLines(b);
 assert.equal(out.cleared,1);assert.equal(out.board[17][0],'L');assert.equal(out.board[0].every(x=>x===null),true);
});
test('shadow projection does not mutate source and visual overlay has 18x10 cells',()=>{
 const s=makeFallingState(12001),row=projectedRow(s),v=renderFallCells(s);
 assert.ok(row>=s.active.row);
 assert.equal(v.length,FALL_HEIGHT);assert.equal(v[0].length,FALL_WIDTH);
 assert.equal(s.board.flat().filter(Boolean).length,0);
});
test('stage goals get harder; stage rewards require a real win',()=>{
 for(const level of [12001,12002,12003,12004,12300,13999,14000]){
  const c=fallingConfig(level);
  assert.ok(c.goal>=1);assert.ok(c.interval>=135&&c.interval<=790);
  const s=makeFallingState(level);assert.equal(fallingWon(s,c),false);
  const winner={...s,over:true,won:true,lines:c.goal,score:c.goal,drops:c.goal,bestCombo:c.goal};
  assert.equal(fallingWon(winner,c),true);assert.ok(fallingStars(winner,c)>=1);
 }
 assert.throws(()=>fallingConfig(14001),RangeError);
});

test('Blockfall Bonus is playable without counting as a fourth campaign stage',()=>{
 const first=12001,cfg=fallingConfig(first),game=makeFallingState(first),board=emptyFallBoard();
 for(let c=0;c<6;c++)board[17][c]='J';
 const done=hardDropFalling({...game,board,active:{type:'I',cells:[[0,0],[0,1],[0,2],[0,3]],row:17,col:6}},cfg);
 assert.equal(done.won,true);assert.equal(done.over,true);assert.equal(done.lines,1);
 assert.equal(TOTAL_STAGES,3);
 assert.equal(awardStage(initialProgress(),first,done).earned,0);
 assert.equal(purchaseStage(initialProgress(),12002).reason,'invalid');
});
