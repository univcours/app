import test from 'node:test';
import assert from 'node:assert/strict';
import {runMove,canPlace,hasMove,SIZE,seededRng} from '../web/engine.js';
import {startStage,applySectorTurn,stageWon,TOTAL_STAGES} from '../web/stages.js';

test('750 random full games and thousands of legal moves cannot corrupt board, score or boss logic',()=>{
 let games=0,turns=0;
 for(let level=1;level<=TOTAL_STAGES;level++){
  for(let seed=1;seed<=250;seed++){
   let state=startStage(level);
   const rng=seededRng(seed*811+level);
   let count=0;
   while(!state.over&&count<120){
    const moves=[];
    for(let i=0;i<state.tray.length;i++){
     const shape=state.tray[i];
     if(!shape)continue;
     for(let row=0;row<SIZE;row++)for(let col=0;col<SIZE;col++)
      if(canPlace(state.board,shape,row,col))moves.push([i,row,col]);
    }
    assert.ok(moves.length>0,'available move must exist when not over');
    const [index,row,col]=moves[Math.floor(rng()*moves.length)];
    const out=runMove(state,index,row,col);
    assert.ok(out,'legal engine move should never fail');
    const next={...out.state};
    next.clears=(state.clears||0)+out.groups;
    next.rows=(state.rows||0)+out.rows;
    next.columns=(state.columns||0)+out.columns;
    next.squares=(state.squares||0)+out.squares;
    next.cellsCleared=(state.cellsCleared||0)+out.cleared;
    next.clearingMoves=(state.clearingMoves||0)+(out.groups>0?1:0);
    next.maxCombo=Math.max(state.maxCombo||0,next.combo||0);
    state=applySectorTurn(next,out);
    if(stageWon(state))state={...state,over:true,won:true};
    assert.equal(state.board.length,SIZE);
    for(const cells of state.board){
     assert.equal(cells.length,SIZE);
     assert.ok(cells.every(v=>v===0||v===1),'board must remain binary');
    }
    assert.ok(Number.isFinite(state.score)&&state.score>=0,'score must remain valid');
    assert.ok(state.bossHp>=0&&state.bossHp<=3,'boss health must stay within bounds');
    if(state.over&&!state.won)
     assert.equal(hasMove(state.board,state.tray),false,'no false game over while a move exists');
    count++;turns++;
   }
   games++;
  }
 }
 assert.equal(games,750);
 console.log('[NovaGrid] Fuzz review:',games,'full simulated games,',turns,'legal moves, zero invariant failures');
});
