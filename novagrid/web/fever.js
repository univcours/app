/* Earned by clearing real lines. Fever gives a short extra score bonus,
   never an advantage in online leaderboards (this mode has no ranked server). */
export const FEVER_DURATION=5;
export function advanceFever(previous={},groups=0,combo=0,gained=0){
 const meter=Math.max(0,Math.min(100,Number(previous.fever)||0));
 const turns=Math.max(0,Math.min(FEVER_DURATION,Number(previous.feverTurns)||0));
 if(turns>0)return {
  fever:turns===1?0:100,feverTurns:turns-1,
  bonus:Math.max(0,Math.floor(gained)),activated:false,active:true
 };
 const charge=groups>0?groups*28+Math.min(combo,5)*9:-4;
 const newMeter=Math.max(0,Math.min(100,meter+charge));
 if(newMeter>=100)return {fever:100,feverTurns:FEVER_DURATION,bonus:0,activated:true,active:true};
 return {fever:newMeter,feverTurns:0,bonus:0,activated:false,active:false};
}
