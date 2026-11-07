/* NovaGrid tall, full-screen real Block Puzzle. No fake extra grid rows.
 * 10 columns x 12 rows, with row/column clears and a guaranteed playable
 * early tray. Separate save key protects historic 9x9 achievements.
 */
import {PATTERNS,seededRng,hashDate} from './engine.js';
import {intensityForMoves,maxPieceCells} from './progressive.js';
export const GLASS_COLS=10,GLASS_ROWS=12;
// Powerful 3x3 bombs are earned rarely by BOTH score and genuine cleared lines.
// Milestones are deterministic and one-time per run; they cannot be farmed by tapping.
export const RARE_BOMB_MILESTONES=Object.freeze([
 {score:5000,lines:18},{score:14500,lines:45},{score:32000,lines:95},
 {score:56000,lines:155},{score:90000,lines:240}
]);
export const MAX_BOMBS=2;
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
  round:1,fever:0,feverTurns:0,usedUndo:false,over:false,
  bombs:0,bombMilestone:0,totalLinesCleared:0};
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
 // Real scoring: placement itself is worth ZERO. Multi-line clears pay more.
 next.combo=result.groups?Math.max(result.groups,Math.min(state.combo+1,8)):0;
 const gained=result.groups===0?0:Math.round(
  120*result.groups*(1+.65*(result.groups-1))+
  18*Math.max(0,next.combo-1)*result.groups
 );
 next.score+=gained;
 next.totalLinesCleared=(state.totalLinesCleared||0)+result.groups;
 next.bombs=Math.max(0,Math.floor(state.bombs||0));
 next.bombMilestone=Math.max(0,Math.floor(state.bombMilestone||0));
 let earnedBombs=0;
 while(result.groups>0&&next.bombMilestone<RARE_BOMB_MILESTONES.length&&next.bombs<MAX_BOMBS){
  const milestone=RARE_BOMB_MILESTONES[next.bombMilestone];
  if(next.score<milestone.score||next.totalLinesCleared<milestone.lines)break;
  next.bombs++;next.bombMilestone++;earnedBombs++;
 }
 if(next.tray.every(x=>!x)){
  const rng=seededRng(state.seed);
  let tray=drawGlassTray(rng,emptyGlassBoard(),0);
  for(let i=0;i<Math.floor(next.moves/3);i++)tray=drawGlassTray(rng,next.board,(i+1)*3);
  next.tray=tray;
 }
 next.over=!hasGlassMove(next.board,next.tray);
 return {state:next,gained,groups:result.groups,rows:result.rows,columns:result.columns,squares:0,cleared:result.cleared,earnedBombs};
}


export function bombProgress(state){
 const index=Math.min(RARE_BOMB_MILESTONES.length,Math.max(0,Math.floor(state.bombMilestone||0)));
 if(index>=RARE_BOMB_MILESTONES.length)return {ready:false,complete:true,percent:100};
 const milestone=RARE_BOMB_MILESTONES[index];
 const scoreProgress=Math.max(0,Math.min(1,(state.score||0)/milestone.score));
 const lineProgress=Math.max(0,Math.min(1,(state.totalLinesCleared||0)/milestone.lines));
 return {ready:(state.bombs||0)>0,complete:false,
  percent:Math.round(100*Math.min(scoreProgress,lineProgress)),
  scoreGoal:milestone.score,linesGoal:milestone.lines};
}

export function detonateGlassBomb(state,row,col){
 if(state.mode!=='classic'||state.over||!(state.bombs>0))return null;
 if(!Number.isInteger(row)||!Number.isInteger(col)||row<0||col<0||row>=GLASS_ROWS||col>=GLASS_COLS)return null;
 const nextBoard=state.board.map(line=>[...line]);
 let removed=0;
 for(let r=Math.max(0,row-1);r<=Math.min(GLASS_ROWS-1,row+1);r++)
  for(let c=Math.max(0,col-1);c<=Math.min(GLASS_COLS-1,col+1);c++){
   if(nextBoard[r][c]){nextBoard[r][c]=0;removed++;}
  }
 if(!removed)return null; // Empty targets do not consume a rare bomb.
 const next={...state,board:nextBoard,bombs:state.bombs-1,combo:0};
 next.over=!hasGlassMove(next.board,next.tray);
 // Bombs are a tactical rescue only: NO points, lines, charge, XP or drops.
 return {state:next,removed,center:[row,col],gained:0};
}
