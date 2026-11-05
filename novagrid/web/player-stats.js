/* Honest offline personal stats. Worldwide rankings require a secure service. */
export function normalizeStats(s){
 const n=x=>Number.isSafeInteger(x)?Math.max(0,x):0;
 return {games:n(s?.games),totalScore:n(s?.totalScore),highest:n(s?.highest),
  bestMoves:n(s?.bestMoves),lines:n(s?.lines),
  bestCombo:n(s?.bestCombo),bestIntensity:n(s?.bestIntensity),
  history:Array.isArray(s?.history)?s.history.filter(x=>x&&Number.isFinite(x.score)).slice(-30):[]};
}
export function recordFinished(stats,game){
 if(!game||!Number.isFinite(game.score)||game.score<0)return normalizeStats(stats);
 const s=normalizeStats(stats),score=Math.floor(game.score);
 s.games++;s.totalScore+=score;s.highest=Math.max(s.highest,score);
 s.bestMoves=Math.max(s.bestMoves,Math.floor(game.moves||game.drops||0));
 s.lines+=Math.max(0,Math.floor(game.lines||game.clears||0));
 s.bestCombo=Math.max(s.bestCombo,Math.floor(game.combo||0));
 s.bestIntensity=Math.max(s.bestIntensity,Math.floor(game.intensity||1));
 s.history.push({mode:game.mode==='falling'?'blockfall':'classic',score,date:new Date().toISOString().slice(0,10),assisted:!!game.assisted});
 s.history=s.history.slice(-30);
 return s;
}
