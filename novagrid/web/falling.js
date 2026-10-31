/* NovaGrid Blockfall: original falling tetromino puzzle, no external assets. */
import {seededRng,hashDate} from './engine.js';
export const FALL_WIDTH=10,FALL_HEIGHT=18;
export const FALL_SHAPES=Object.freeze({
 I:[[0,0],[0,1],[0,2],[0,3]],
 O:[[0,0],[0,1],[1,0],[1,1]],
 T:[[0,0],[0,1],[0,2],[1,1]],
 S:[[0,1],[0,2],[1,0],[1,1]],
 Z:[[0,0],[0,1],[1,1],[1,2]],
 J:[[0,0],[1,0],[1,1],[1,2]],
 L:[[0,2],[1,0],[1,1],[1,2]]
});
export const FALL_TYPES=Object.keys(FALL_SHAPES);
export const FALL_PALETTE={I:'#4eeaff',O:'#ffdd69',T:'#bd81ff',S:'#58eabb',Z:'#ff689c',J:'#6893ff',L:'#ffab66'};
export function emptyFallBoard(){return Array.from({length:FALL_HEIGHT},()=>Array(FALL_WIDTH).fill(null));}
export function fallingConfig(level,sectorStart=12001){
 const local=level-sectorStart;
 if(!Number.isInteger(local)||local<0||local>=2000)throw RangeError('Invalid Blockfall level');
 const tier=Math.floor(local/40);
 const kinds=['lines','score','drops','combos'];
 const kind=kinds[local%4];
 const goal=kind==='lines'?1+Math.floor(tier/2):
  kind==='score'?150+tier*80:
  kind==='drops'?8+tier*2:2+Math.floor(tier/6);
 return {kind,goal,interval:Math.max(135,790-tier*13),tier,level};
}
export function shuffledBag(level,bagIndex){
 const rng=seededRng(hashDate('novagrid-blockfall-'+level+'-'+bagIndex));
 const pieces=[...FALL_TYPES];
 for(let i=pieces.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[pieces[i],pieces[j]]=[pieces[j],pieces[i]];}
 return pieces;
}
export function pieceAt(level,index){
 if(!Number.isInteger(index)||index<0)throw RangeError('piece index');
 return shuffledBag(level,Math.floor(index/7))[index%7];
}
export function shapeFor(type){return FALL_SHAPES[type].map(([r,c])=>[r,c]);}
export function rotateShape(cells){
 const maxR=Math.max(...cells.map(([r])=>r));
 const rotated=cells.map(([r,c])=>[c,maxR-r]);
 const minR=Math.min(...rotated.map(p=>p[0])),minC=Math.min(...rotated.map(p=>p[1]));
 return rotated.map(([r,c])=>[r-minR,c-minC]);
}
export function canFallAt(board,cells,row,col){
 return cells.every(([r,c])=>row+r>=0&&row+r<FALL_HEIGHT&&col+c>=0&&col+c<FALL_WIDTH&&!board[row+r][col+c]);
}
export function spawnPiece(board,level,index){
 const type=pieceAt(level,index),cells=shapeFor(type);
 const width=Math.max(...cells.map(p=>p[1]))+1,col=Math.floor((FALL_WIDTH-width)/2);
 const active={type,cells,row:0,col};
 return canFallAt(board,cells,active.row,active.col)?active:null;
}
export function makeFallingState(level){
 const board=emptyFallBoard(),active=spawnPiece(board,level,0);
 return {mode:'falling',stageLevel:level,board,active,nextType:pieceAt(level,1),nextIndex:1,
  score:0,lines:0,drops:0,combo:0,bestCombo:0,over:false,won:false};
}
export function tryMoveFalling(state,deltaCol){
 if(state.over||!state.active)return state;
 const active={...state.active,col:state.active.col+deltaCol};
 return canFallAt(state.board,active.cells,active.row,active.col)?{...state,active}:state;
}
export function tryRotateFalling(state){
 if(state.over||!state.active)return state;
 const cells=rotateShape(state.active.cells);
 for(const [dr,dc] of [[0,0],[0,-1],[0,1],[0,-2],[0,2],[-1,0]]){
  const active={...state.active,cells,row:state.active.row+dr,col:state.active.col+dc};
  if(canFallAt(state.board,cells,active.row,active.col))return {...state,active};
 }
 return state;
}
export function projectedRow(state){
 if(!state.active)return null;
 let row=state.active.row;
 while(canFallAt(state.board,state.active.cells,row+1,state.active.col))row++;
 return row;
}
export function clearFallLines(board){
 const intact=board.filter(row=>!row.every(Boolean));
 const cleared=FALL_HEIGHT-intact.length;
 const top=Array.from({length:cleared},()=>Array(FALL_WIDTH).fill(null));
 return {board:[...top,...intact.map(row=>[...row])],cleared};
}
export function fallingObjective(state,config){
 switch(config.kind){
  case 'lines':return state.lines;
  case 'score':return state.score;
  case 'drops':return state.drops;
  case 'combos':return state.bestCombo;
  default:return 0;
 }
}
export function fallingWon(state,config){
 return !!state.over&&!!state.won&&fallingObjective(state,config)>=config.goal;
}
export function fallingStars(state,config){
 if(!fallingWon(state,config))return 0;
 const ratio=fallingObjective(state,config)/config.goal;
 return ratio>=2.0?3:ratio>=1.35?2:1;
}
function lockPiece(state,config){
 const board=state.board.map(row=>[...row]),a=state.active;
 for(const [r,c] of a.cells)board[a.row+r][a.col+c]=a.type;
 const clear=clearFallLines(board),combo=clear.cleared>0?state.combo+1:0;
 const gained=[0,120,340,580,950][clear.cleared]||1200;
 const score=state.score+gained*(config.tier+1)+Math.max(0,combo-1)*35+(state.softPoints||0);
 const next={...state,board:clear.board,score,lines:state.lines+clear.cleared,
  drops:state.drops+1,combo,bestCombo:Math.max(state.bestCombo,combo),
  softPoints:0,nextIndex:state.nextIndex+1,nextType:pieceAt(state.stageLevel,state.nextIndex+1)};
 const success=fallingObjective(next,config)>=config.goal;
 if(success)return {...next,active:null,won:true,over:true,lastClear:clear.cleared};
 const active=spawnPiece(clear.board,state.stageLevel,state.nextIndex);
 return {...next,active,won:false,over:!active,lastClear:clear.cleared};
}
export function stepFalling(state,config,soft=false){
 if(state.over||!state.active)return state;
 const a=state.active;
 if(canFallAt(state.board,a.cells,a.row+1,a.col)){
  return {...state,active:{...a,row:a.row+1},softPoints:(state.softPoints||0)+(soft?1:0),lastClear:0};
 }
 return lockPiece(state,config);
}
export function hardDropFalling(state,config){
 if(state.over||!state.active)return state;
 const row=projectedRow(state),distance=row-state.active.row;
 return lockPiece({...state,active:{...state.active,row},softPoints:(state.softPoints||0)+distance*2},config);
}
export function renderFallCells(state){
 const board=state.board.map(row=>[...row]);
 if(state.active){
  const ghost=projectedRow(state);
  for(const [r,c] of state.active.cells)if(!board[ghost+r][state.active.col+c])board[ghost+r][state.active.col+c]='ghost';
  for(const [r,c] of state.active.cells)board[state.active.row+r][state.active.col+c]=state.active.type;
 }
 return board;
}
