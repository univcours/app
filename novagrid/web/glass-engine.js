/* NovaGrid tall, full-screen real Block Puzzle. No fake extra grid rows.
 * 10 columns x 12 rows, with row/column clears and a guaranteed playable
 * early tray. Separate save key protects historic 9x9 achievements.
 */
import {PATTERNS,seededRng,hashDate} from './engine.js';
import {intensityForMoves,maxPieceCells} from './progressive.js';
export const GLASS_COLS=10,GLASS_ROWS=12;
export function emptyGlassBoard(){
 return Array.from({length:GLASS_ROWS},()=>Array(GLASS_COLS).fill(0));
}
export function isGlassBoard(board){
 return Array.isArray(board)&&board.length===GLASS_ROWS&&
  board.every(row=>Array.isArray(row)&&row.length===GLASS_COLS&&row.every(cell=>Number.isInteger(cell)&&cell>=0&&cell<=6));
}
export function canPlaceGlass(board,shape,row,col){
 return !!shape&&shape.every(([dr,dc])=>row+dr>=0&&col+dc>=0&&row+dr<GLASS_ROWS&&col+dc<GLASS_COLS&&!board[row+dr][col+dc]);
}
export function hasGlassMove(board,tray){
 return tray.some(shape=>shape&&Array.from({length:GLASS_ROWS},(_,r)=>r).some(r=>
  Array.from({length:GLASS_COLS},(_,c)=>c).some(c=>canPlaceGlass(board,shape,r,c))));
}
export function drawGlassTray(rng,board,moves){
 const cap=maxPieceCells(intensityForMoves(moves));
 const options=PATTERNS.filter(s=>s.length<=cap).map(s=>s.map(cell=>[...cell]));
 const playable=options.filter(p=>hasGlassMove(board,[p]));
 const tray=Array.from({length:3},()=>options[Math.floor(rng()*options.length)]).map(s=>s.map(p=>[...p]));
 if(playable.length>0&&tray.filter(p=>hasGlassMove(board,[p])).length<(moves<36?2:1)){
  let needed=moves<36?2:1;
  for(let i=0;i<tray.length&&needed>0;i++){
   if(hasGlassMove(board,[tray[i]])){needed--;continue;}
   tray[i]=playable[Math.floor(rng()*playable.length)].map(p=>[...p]);needed--;
  }
 }
 return tray;
}
export function makeGlassGame(){
 const seed=Math.floor(Math.random()*4294967295),board=emptyGlassBoard(),rng=seededRng(seed);
 return {mode:'classic',seed,board,tray:drawGlassTray(rng,board,0),score:0,moves:0,combo:0,
  round:1,fever:0,feverTurns:0,usedUndo:false,over:false};
}
export function placeGlass(board,shape,row,col,color=1){
 if(!canPlaceGlass(board,shape,row,col))return null;
 const next=board.map(line=>[...line]);
 for(const [dr,dc] of shape)next[row+dr][col+dc]=Math.max(1,Math.min(6,Math.floor(color)||1));
 const cleared=new Set();let rows=0,columns=0;
 for(let r=0;r<GLASS_ROWS;r++)if(next[r].every(Boolean)){
  rows++;for(let c=0;c<GLASS_COLS;c++)cleared.add(r+','+c);
 }
 for(let c=0;c<GLASS_COLS;c++)if(next.every(line=>line[c])){
  columns++;for(let r=0;r<GLASS_ROWS;r++)cleared.add(r+','+c);
 }
 for(const value of cleared){const [r,c]=value.split(',').map(Number);next[r][c]=0;}
 return {board:next,rows,columns,groups:rows+columns,squares:0,
  cleared:cleared.size,placed:shape.length};
}
export function runGlassMove(state,trayIndex,row,col){
 const shape=state.tray[trayIndex];
 const result=placeGlass(state.board,shape,row,col,1+(state.moves+trayIndex*2)%6);
 if(!result)return null;
 const next={...state,board:result.board,tray:state.tray.map((x,i)=>i===trayIndex?null:x),moves:state.moves+1};
 next.combo=result.groups?state.combo+1:0;
 const gained=result.placed+result.groups*(24+Math.min(next.combo,7)*6)+Math.max(result.groups-1,0)*25;
 next.score+=gained;
 if(next.tray.every(x=>!x)){
  const rng=seededRng(state.seed);
  let tray=drawGlassTray(rng,emptyGlassBoard(),0);
  for(let i=0;i<Math.floor(next.moves/3);i++)tray=drawGlassTray(rng,next.board,(i+1)*3);
  next.tray=tray;
 }
 next.over=!hasGlassMove(next.board,next.tray);
 return {state:next,gained,groups:result.groups,rows:result.rows,columns:result.columns,squares:0,cleared:result.cleared};
}
