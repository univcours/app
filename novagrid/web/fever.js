/* Nova Fever: earned through skillful line clears, never paid or forced by ads. */
export const FEVER_TARGET=100;
export const FEVER_DURATION=5;
export function advanceFever(previous={},groups=0,combo=0){
 const active=Math.max(0,Math.min(FEVER_DURATION,Math.floor(previous.activeMoves||0)));
 if(active>0)return {fever:{meter:0,activeMoves:active-1},multiplier:2,activated:false};
 const meter=Math.min(FEVER_TARGET,Math.max(0,Math.floor(previous.meter||0))+
   Math.max(0,Math.floor(groups))*28+(groups>0&&combo>=2?12:0));
 if(meter>=FEVER_TARGET)return {fever:{meter:0,activeMoves:FEVER_DURATION-1},multiplier:2,activated:true};
 return {fever:{meter,activeMoves:0},multiplier:1,activated:false};
}
export function feverDisplay(value={}){
 const active=!!value.activeMoves;
 return {active,meter:active?100:Math.max(0,Math.min(100,value.meter||0)),remaining:Math.max(0,value.activeMoves||0)};
}
