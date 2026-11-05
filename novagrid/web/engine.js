import {intensityForMoves,maxPieceCells} from './progressive.js';
import {advanceFever} from './fever.js';
/* NovaGrid original block-placement puzzle engine — deterministic and dependency-free. */
export const SIZE = 9;
export const PATTERNS = [
 [[0,0]], [[0,0],[0,1]], [[0,0],[1,0]],
 [[0,0],[0,1],[0,2]], [[0,0],[1,0],[2,0]],
 [[0,0],[0,1],[1,0]], [[0,0],[0,1],[1,1]], [[0,0],[1,0],[1,1]],
 [[0,1],[1,0],[1,1]], [[0,0],[0,1],[1,0],[1,1]],
 [[0,0],[0,1],[0,2],[0,3]], [[0,0],[1,0],[2,0],[3,0]],
 [[0,0],[1,0],[2,0],[2,1]], [[0,0],[0,1],[0,2],[1,1]],
 [[0,0],[0,1],[1,1],[1,2]], [[0,1],[0,2],[1,0],[1,1]],
 [[0,0],[0,1],[0,2],[1,0],[1,1],[1,2]],
 [[0,0],[1,0],[2,0],[0,1],[1,1],[2,1]],
 [[0,0],[0,1],[0,2],[1,0],[1,1],[1,2],[2,0],[2,1],[2,2]]
];
export function seededRng(seed) {
 let s = seed >>> 0 || 1234567;
 return () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return (s >>> 0)/4294967296; };
}
export function hashDate(date) {
 let n=2166136261; for (const c of date) {n^=c.charCodeAt(0);n=Math.imul(n,16777619);}return n>>>0;
}
export function emptyBoard(){return Array.from({length:SIZE},()=>Array(SIZE).fill(0));}
export function canPlace(board,shape,row,col){return shape.every(([dr,dc])=>row+dr>=0&&col+dc>=0&&row+dr<SIZE&&col+dc<SIZE&&!board[row+dr][col+dc]);}
export function anyPlacement(board,shape){for(let r=0;r<SIZE;r++)for(let c=0;c<SIZE;c++)if(canPlace(board,shape,r,c))return true;return false;}
export function hasMove(board,tray){return tray.some(shape=>shape!==null&&anyPlacement(board,shape));}
export function place(board,shape,row,col){
 if(!shape||!canPlace(board,shape,row,col))return null;
 const b=board.map(line=>[...line]);
 for(const [dr,dc] of shape)b[row+dr][col+dc]=1;
 const clear=new Set();let groups=0,rows=0,columns=0,squares=0;
 for(let r=0;r<SIZE;r++)if(b[r].every(Boolean)){groups++;rows++;for(let c=0;c<SIZE;c++)clear.add(`${r},${c}`);}
 for(let c=0;c<SIZE;c++)if(b.every(line=>line[c])){groups++;columns++;for(let r=0;r<SIZE;r++)clear.add(`${r},${c}`);}
 for(let sr=0;sr<SIZE;sr+=3)for(let sc=0;sc<SIZE;sc+=3){
 let full=true;for(let r=sr;r<sr+3;r++)for(let c=sc;c<sc+3;c++)if(!b[r][c])full=false;
 if(full){groups++;squares++;for(let r=sr;r<sr+3;r++)for(let c=sc;c<sc+3;c++)clear.add(`${r},${c}`);}
 }
 for(const key of clear){const [r,c]=key.split(',').map(Number);b[r][c]=0;}
 return {board:b,groups,rows,columns,squares,cleared:clear.size,placed:shape.length};
}
export function drawTray(rng,board,moves=0){
 const intensity=intensityForMoves(moves);
 const cap=maxPieceCells(intensity);
 const options=PATTERNS.filter(p=>p.length<=cap).map(p=>p.map(cell=>[...cell]));
 // Offer at least one playable piece where available, but not an automatic win.
 const playable=options.filter(p=>anyPlacement(board,p));
 const tray=Array.from({length:3},()=>options[Math.floor(rng()*options.length)]);
 // During the first 36 moves, offer at least two playable options to build confidence.
 if(playable.length>0){
  const minimum=intensity<=2?2:1;
  const existing=tray.filter(p=>anyPlacement(board,p)).length;
  for(let k=existing;k<minimum;k++){
   const index=tray.findIndex(p=>!anyPlacement(board,p));
   if(index<0)break;
   tray[index]=playable[Math.floor(rng()*playable.length)];
  }
 }
 return tray.map(p=>p.map(x=>[...x]));
}
export function makeGame(mode='classic',date=new Date().toISOString().slice(0,10)){
 const seed=mode==='daily'?hashDate(date):Math.floor(Math.random()*4294967295);
 const rng=seededRng(seed),board=emptyBoard();
 return {mode,date,seed,round:1,board,tray:drawTray(rng,board,0),score:0,combo:0,moves:0,usedUndo:false,over:false,fever:{meter:0,activeMoves:0},clears:0,assisted:false};
}
export function runMove(state,trayIndex,row,col){
 const shape=state.tray[trayIndex],result=place(state.board,shape,row,col);
 if(!result)return null;
 const next={...state,board:result.board,tray:state.tray.map((s,i)=>i===trayIndex?null:s),moves:state.moves+1};
 next.combo=result.groups?state.combo+1:0;
 next.clears=(state.clears||0)+result.groups;
 const phase=advanceFever(state.fever,result.groups,next.combo);
 next.fever=phase.fever;
 const gained=(result.placed+result.groups*(18+Math.min(7,next.combo)*5)+Math.max(0,result.groups-1)*22)*phase.multiplier;
 next.score+=gained;
 next.lastFeverTriggered=phase.activated;
 if(next.tray.every(x=>x===null)){
 // Replay deterministic series by advancing the RNG once per generated tray.
 const rng=seededRng(state.seed);let tray=drawTray(rng,emptyBoard(),0);
 for(let i=0;i<Math.floor(next.moves/3);i++)tray=drawTray(rng,next.board,(i+1)*3);
 next.tray=tray;
 }
 next.over=!hasMove(next.board,next.tray);
 return {state:next,gained,groups:result.groups,rows:result.rows,columns:result.columns,squares:result.squares,cleared:result.cleared,feverActivated:phase.activated,feverMultiplier:phase.multiplier};
}
