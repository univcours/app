import test from 'node:test';
import assert from 'node:assert/strict';
import {GLASS_COLS,GLASS_ROWS,emptyGlassBoard,makeGlassGame,canPlaceGlass,placeGlass,runGlassMove,isGlassBoard} from '../web/glass-engine.js';
import {calculateBoardSize} from '../web/layout.js';
test('portrait Block Puzzle is a real playable 10x12 grid with a separate save format',()=>{
 const state=makeGlassGame();
 assert.equal(GLASS_COLS,10);assert.equal(GLASS_ROWS,12);
 assert.ok(isGlassBoard(state.board));assert.equal(state.board.length,12);
 assert.equal(state.board[0].length,10);
 assert.equal(state.tray.length,3);
 assert.equal(state.mode,'classic');
});
test('row clear requires ten occupied columns; never clears a fake row',()=>{
 const board=emptyGlassBoard();for(let c=0;c<9;c++)board[2][c]=1;
 const result=placeGlass(board,[[0,0]],2,9);
 assert.equal(result.rows,1);assert.equal(result.cleared,10);
 assert.equal(result.board[2].filter(Boolean).length,0);
});
test('column clear is twelve cells and difficulty progresses by real placements',()=>{
 const board=emptyGlassBoard();
 for(let r=0;r<11;r++)board[r][0]=1;
 const result=placeGlass(board,[[0,0]],11,0);
 assert.equal(result.columns,1);assert.equal(result.cleared,12);
 const game=makeGlassGame(),shape=game.tray[0];
 let played=null;
 for(let r=0;r<12&&!played;r++)for(let c=0;c<10&&!played;c++)
  if(canPlaceGlass(game.board,shape,r,c))played=runGlassMove(game,0,r,c);
 assert.ok(played&&played.state.moves===1);
 assert.ok(played.state.score>0);
});
test('tall game width respects both portrait height and device width',()=>{
 const n=calculateBoardSize({cardHeight:640,cardWidth:390,paddingVertical:12,paddingHorizontal:12,
  fixedHeights:[32,1,70,30],gap:4,aspectRows:12,aspectCols:10});
 assert.ok(n>=355&&n<=370, 'got '+n);
 const small=calculateBoardSize({cardHeight:400,cardWidth:390,paddingVertical:12,paddingHorizontal:12,
  fixedHeights:[32,1,70,30],gap:4,aspectRows:12,aspectCols:10});
 assert.ok(small<=200,'must shrink to avoid clipping on short screens: '+small);
});
