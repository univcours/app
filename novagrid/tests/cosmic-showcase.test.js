import test from 'node:test';
import assert from 'node:assert/strict';
import {makeGlassGame,emptyGlassBoard,runGlassMove,detonateGlassBomb,
 bombProgress,RARE_BOMB_MILESTONES} from '../web/glass-engine.js';
import {makeFallingState,emptyFallBoard,hardDropFalling,fallingConfig} from '../web/falling.js';
import {readFileSync} from 'node:fs';

test('Block Puzzle placements with no completed lines score ZERO',()=>{
 const state=makeGlassGame();
 const result=runGlassMove({...state,tray:[[[0,0]],null,null]},0,1,1);
 assert.ok(result);
 assert.equal(result.gained,0);
 assert.equal(result.state.score,0);
 assert.equal(result.state.combo,0);
 assert.equal(result.earnedBombs,0);
});
test('Two simultaneous row clears produce more than two single clears and combo >=2',()=>{
 const one=emptyGlassBoard();
 for(let c=0;c<9;c++)one[0][c]=1;
 const single=runGlassMove({...makeGlassGame(),board:one,tray:[[[0,0]],null,null]},0,0,9);
 assert.equal(single.groups,1);
 assert.ok(single.gained>0);
 const two=emptyGlassBoard();
 for(let c=0;c<9;c++){two[0][c]=1;two[1][c]=2;}
 const multi=runGlassMove({...makeGlassGame(),board:two,tray:[[[0,0],[1,0]],null,null]},0,0,9);
 assert.equal(multi.groups,2);
 assert.equal(multi.state.combo,2);
 assert.ok(multi.gained>single.gained*2,'simultaneous 2-line skill gets extra bonus');
 assert.equal(multi.state.board[0].filter(Boolean).length,0);
 assert.equal(multi.state.board[1].filter(Boolean).length,0);
});
test('Rare bombs require BOTH high real line total and actual threshold score',()=>{
 const config=RARE_BOMB_MILESTONES[0];
 const board=emptyGlassBoard();
 for(let c=0;c<9;c++)board[3][c]=1;
 const base={...makeGlassGame(),board,tray:[[[0,0]],null,null],
  score:config.score-200,totalLinesCleared:config.lines-1};
 const insufficient=runGlassMove(base,0,3,9);
 assert.equal(insufficient.groups,1);
 assert.equal(insufficient.earnedBombs,0);
 const earned=runGlassMove({...base,score:config.score-100},0,3,9);
 assert.equal(earned.earnedBombs,1);
 assert.equal(earned.state.bombs,1);
 assert.equal(earned.state.bombMilestone,1);
 assert.equal(bombProgress(earned.state).ready,true);
 const again=runGlassMove({...earned.state,tray:[[[0,0]],null,null]},0,3,0);
 assert.equal(again.earnedBombs,0,'a claimed milestone cannot pay again');
});
test('Tactical bomb clears a REAL 3x3 region without increasing score or milestones',()=>{
 const board=emptyGlassBoard();for(let r=4;r<=6;r++)for(let c=4;c<=6;c++)board[r][c]=2;
 const state={...makeGlassGame(),board,bombs:1,score:8800,totalLinesCleared:25,bombMilestone:1};
 assert.equal(detonateGlassBomb(state,1,1),null,'empty target cannot waste a rare bomb');
 const hit=detonateGlassBomb(state,5,5);
 assert.equal(hit.removed,9);
 assert.equal(hit.state.score,state.score);
 assert.equal(hit.state.bombs,0);
 assert.equal(hit.state.totalLinesCleared,state.totalLinesCleared);
 assert.equal(hit.state.bombMilestone,state.bombMilestone);
 assert.equal(hit.state.board.flat().filter(Boolean).length,0);
 assert.equal(detonateGlassBomb(hit.state,5,5),null);
});
test('Blockfall gravity and hard-drop never score without a line clear',()=>{
 const config={...fallingConfig(12001),kind:'score',goal:Number.MAX_SAFE_INTEGER};
 const state=makeFallingState(12001);
 const dropped=hardDropFalling(state,config);
 assert.equal(dropped.lines,0);
 assert.equal(dropped.score,0);
});
test('Blockfall clears and pays an extra reward for multiple simultaneous lines',()=>{
 const config={...fallingConfig(12001),kind:'score',goal:Number.MAX_SAFE_INTEGER};
 const board=emptyFallBoard();
 for(let c=0;c<9;c++)board[17][c]='I';
 const single=hardDropFalling({...makeFallingState(12001),board,
  active:{type:'I',cells:[[0,0]],row:17,col:9}},config);
 assert.equal(single.lines,1);
 assert.ok(single.score>0);
 const two=emptyFallBoard();for(let c=0;c<9;c++){two[16][c]='I';two[17][c]='I';}
 const multi=hardDropFalling({...makeFallingState(12001),board:two,
  active:{type:'O',cells:[[0,0],[1,0]],row:16,col:9}},config);
 assert.equal(multi.lines,2);
 assert.ok(multi.score>single.score*2);
 assert.ok(multi.combo>=2);
});
test('Image-reference look and sounds have live interactive implementation',()=>{
 const text=p=>readFileSync(new URL('../web/'+p,import.meta.url),'utf8');
 assert.match(text('index.html'),/cosmic-showcase\.css/);
 assert.match(text('index.html'),/id="bombBtn"/);
 assert.match(text('app.js'),/detonateGlassBomb\(state,row,col\)/);
 assert.match(text('audio.js'),/glassCrack/);
 assert.match(text('falling-ui.js'),/fallGlassFx/);
 assert.match(text('cosmic-showcase.css'),/nova-bomb-panel/);
});
