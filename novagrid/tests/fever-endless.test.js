import test from 'node:test';import assert from 'node:assert/strict';
import {advanceFever,feverDisplay} from '../web/fever.js';
import {makeGame,runMove,emptyBoard} from '../web/engine.js';
test('Fever is earned by real groups and gives limited doubled score',()=>{
 let f={meter:0,activeMoves:0},activated=false;
 for(let i=0;i<10;i++){
  const next=advanceFever(f,1,i+1);
  f=next.fever;
  if(next.activated){activated=true;break;}
 }
 assert.equal(activated,true);
 assert.equal(feverDisplay(f).active,true);
 const remaining=f.activeMoves;
 for(let i=0;i<remaining;i++){
  const next=advanceFever(f,0,0);
  assert.equal(next.multiplier,2);
  f=next.fever;
 }
 assert.equal(feverDisplay(f).active,false);
 assert.equal(advanceFever(f,0,0).multiplier,1);
});
test('Fever does not trigger for idle placements, multiplier never arises from points bought',()=>{
 let f={meter:0,activeMoves:0};
 for(let i=0;i<200;i++)f=advanceFever(f,0,0).fever;
 assert.deepEqual(f,{meter:0,activeMoves:0});
});
test('endless session remains on the same board mode after a valid placement',()=>{
 const s=makeGame('classic');const m=runMove(s,0,0,0);
 assert.ok(m);assert.equal(m.state.mode,'classic');assert.equal(m.state.over,false);
 assert.equal(m.state.board.length,emptyBoard().length);assert.ok('fever' in m.state);
});