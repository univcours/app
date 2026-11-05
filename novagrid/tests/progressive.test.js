import test from 'node:test';
import assert from 'node:assert/strict';
import {intensityForMoves,maxPieceCells,INTENSITY_CAP,MOVES_PER_INTENSITY} from '../web/progressive.js';
import {drawTray,emptyBoard,hasMove,seededRng,makeGame,runMove} from '../web/engine.js';
test('endless intensity grows steadily every 18 moves and saturates',()=>{
 assert.equal(MOVES_PER_INTENSITY,18);assert.equal(INTENSITY_CAP,9);
 for(const [moves,tier] of [[0,1],[17,1],[18,2],[35,2],[36,3],[90,6],[144,9],[900,9]]){
  assert.equal(intensityForMoves(moves),tier);
 }
});
test('first intensity avoids huge shapes, with later tiers opening more variety',()=>{
 assert.equal(maxPieceCells(1),4);
 assert.equal(maxPieceCells(3),5);
 assert.equal(maxPieceCells(5),6);
 assert.equal(maxPieceCells(9),9);
 for(const moves of [0,12,30,48,100,200]){
  const max=maxPieceCells(intensityForMoves(moves));
  const tray=drawTray(seededRng(123+Math.floor(moves)),emptyBoard(),moves);
  assert.equal(tray.length,3);
  assert.ok(tray.every(shape=>shape.length<=max));
  assert.equal(hasMove(emptyBoard(),tray),true);
 }
});
test('difficulty does not end a run automatically at each threshold',()=>{
 const s=makeGame('classic','2026-11-05');
 const next=runMove(s,0,0,0);
 assert.ok(next);
 assert.equal(next.state.moves,1);
 assert.equal(next.state.over,false);
 assert.equal(next.state.mode,'classic');
});
