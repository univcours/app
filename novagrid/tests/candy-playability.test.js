import test from 'node:test';
import assert from 'node:assert/strict';
import {SIZE,canPlace,runMove,hasMove} from '../web/engine.js';
import {TOTAL_STAGES,stageConfig,startStage,stageWon,applySectorTurn} from '../web/stages.js';
import {CANDY_COLORS} from '../web/arcade-fx.js';
import {readFileSync} from 'node:fs';

function nextState(state,out){
 const n={...out.state};
 n.clears=(state.clears||0)+out.groups;
 n.rows=(state.rows||0)+out.rows;
 n.columns=(state.columns||0)+out.columns;
 n.squares=(state.squares||0)+out.squares;
 n.cellsCleared=(state.cellsCleared||0)+out.cleared;
 n.clearingMoves=(state.clearingMoves||0)+(out.groups>0?1:0);
 n.maxCombo=Math.max(state.maxCombo||0,n.combo||0);
 return applySectorTurn(n,out);
}
function potential(board){
 let n=0;
 for(const row of board){const cells=row.filter(Boolean).length;n+=cells>=5?cells*cells*.25:cells*.45;}
 for(let c=0;c<9;c++){const cells=board.reduce((a,row)=>a+Number(!!row[c]),0);n+=cells>=5?cells*cells*.25:cells*.45;}
 for(let sr=0;sr<9;sr+=3)for(let sc=0;sc<9;sc+=3){
  let cells=0;for(let r=sr;r<sr+3;r++)for(let c=sc;c<sc+3;c++)cells+=Number(!!board[r][c]);
  n+=cells>=5?cells*cells*.30:cells*.55;
 }
 return n;
}
function simulate(level,strategy){
 let s=startStage(level);
 for(let turn=0;turn<80&&!s.over;turn++){
  const picks=[];
  for(let i=0;i<s.tray.length;i++){
   const shape=s.tray[i];if(!shape)continue;
   for(let r=0;r<SIZE;r++)for(let c=0;c<SIZE;c++){
    if(!canPlace(s.board,shape,r,c))continue;
    const out=runMove(s,i,r,c);if(!out)continue;
    const n=nextState(s,out);
    const occ=n.board.flat().filter(Boolean).length;
    const special=level===1?n.candyBursts:level===2?n.rocketShots:n.bombBlasts;
    const h=(n.score-s.score)*(strategy===0?1:2)+out.groups*(strategy===1?180:100)+
      (n.score-s.score)*(strategy===2?1.2:0)+potential(n.board)*(strategy===0?1.5:2.3)-
      occ*(strategy===2?3:1.4)+special*18;
    picks.push({state:n,h});
   }
  }
  if(!picks.length)break;
  picks.sort((a,b)=>b.h-a.h);
  s=picks[0].state;
  if(stageWon(s))return {won:true,turns:turn+1,score:s.score,combos:s.clears};
 }
 return {won:false,score:s.score,turns:s.moves,combos:s.clears};
}
test('three stages can be cleared by a deterministic legal move strategy without cheats',()=>{
 const all=[];
 for(let level=1;level<=TOTAL_STAGES;level++){
  const attempts=[0,1,2].map(strategy=>simulate(level,strategy));
  const winner=attempts.filter(a=>a.won).sort((a,b)=>a.turns-b.turns)[0];
  all.push({level,goal:stageConfig(level).scoreTarget,winner,attempts});
  assert.ok(winner,'Stage '+level+' has no winning path in deterministic legal-move QA: '+JSON.stringify(attempts));
  assert.ok(winner.turns<75,'Stage '+level+' takes too many moves');
 }
 console.log('Candy Arcade playability:',JSON.stringify(all));
});
test('Candy skin, real visuals, audio effects and AdMob safe interstitial bridge all present',()=>{
 const html=readFileSync(new URL('../web/index.html',import.meta.url),'utf8');
 const css=readFileSync(new URL('../web/candy-arcade.css',import.meta.url),'utf8');
 const app=readFileSync(new URL('../web/app.js',import.meta.url),'utf8');
 const sound=readFileSync(new URL('../web/audio.js',import.meta.url),'utf8');
 const ads=readFileSync(new URL('../web/ads.js',import.meta.url),'utf8');
 assert.equal(CANDY_COLORS.length,6);
 assert.match(html,/id="candyFxLayer"/);
 assert.match(html,/candy-arcade.css/);
 for(const color of ['candy-0','candy-1','candy-2','candy-3','candy-4','candy-5'])assert.ok(css.includes('.'+color));
 for(const name of ['rocket','bomb','candy','victory'])assert.ok(sound.includes("kind==='"+name+"'"));
 assert.match(app,/arcadeEffect/);
 assert.match(ads,/interstitial:true,rewarded:true/);
 assert.match(ads,/Date\.now\(\)-last<180000/);
});
