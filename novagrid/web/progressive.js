/* Endless NovaGrid: continuous difficulty, no numbered stages.
 * One intensity increase per 18 successfully placed pieces, capped at 9.
 * Only influences upcoming tray choices; never changes a piece mid-drag.
 */
export const INTENSITY_CAP=9;
export const MOVES_PER_INTENSITY=18;
export function intensityForMoves(moves=0){
 const n=Number.isFinite(moves)?Math.max(0,Math.floor(moves)):0;
 return Math.min(INTENSITY_CAP,1+Math.floor(n/MOVES_PER_INTENSITY));
}
export function maxPieceCells(intensity=1){
 const tier=Math.min(INTENSITY_CAP,Math.max(1,Math.floor(intensity)||1));
 return tier<=2?4:tier<=4?5:tier<=6?6:9;
}
export function intensityLabel(tier,lang='en'){
 const label={ar:'الصعوبة',fr:'Intensité',en:'Intensity'}[lang]||'Intensity';
 return label+' '+Math.max(1,Math.min(INTENSITY_CAP,tier))+'/'+INTENSITY_CAP;
}
