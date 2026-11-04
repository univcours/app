/* Original, procedurally synthesized NovaGrid ambient score.
   No third-party recordings, downloads or licensed musical compositions. */
export const musicPhrase=[0,7,12,10,7,3,5,7,0,5,10,12,15,12,7,3];
export function toneHz(semitones,base=220){return base*Math.pow(2,semitones/12);}
export function createGameAudio({effectsEnabled=true,musicEnabled=true}={}){
 let ctx=null,timer=null,startedByGesture=false,step=0,stage=0;
 let effectOn=!!effectsEnabled,musicOn=!!musicEnabled;
 const AudioClass=typeof window!=='undefined'&&(window.AudioContext||window.webkitAudioContext);
 function acquire(){
  if(!AudioClass)return null;
  if(!ctx){try{ctx=new AudioClass();}catch{return null;}}
  if(ctx.state==='suspended')void ctx.resume().catch(()=>{});
  return ctx;
 }
 function note(freq,start,duration,level=0.02,wave='sine'){
  if(!ctx||ctx.state==='closed')return;
  try{
   const oscillator=ctx.createOscillator(),envelope=ctx.createGain();
   oscillator.type=wave;oscillator.frequency.setValueAtTime(Math.max(40,freq),start);
   envelope.gain.setValueAtTime(0.0001,start);
   envelope.gain.exponentialRampToValueAtTime(level,start+Math.min(duration*.26,.06));
   envelope.gain.exponentialRampToValueAtTime(0.0001,start+duration);
   oscillator.connect(envelope);envelope.connect(ctx.destination);
   oscillator.start(start);oscillator.stop(start+duration+.015);
   oscillator.onended=()=>{oscillator.disconnect();envelope.disconnect();};
  }catch{}
 }
 function nextBeat(){
  if(!ctx||ctx.state!=='running'||!musicOn||document.hidden)return;
  const at=ctx.currentTime+.02,degree=musicPhrase[step%musicPhrase.length];
  note(toneHz(degree,220),at,.49,.0135,'sine');
  if(step%4===0)note(toneHz([-12,-7,-5,-7][(step/4)%4],220),at,1.2,.011,'triangle');
  if(step%8===4)note(toneHz(degree+12,220),at+.16,.25,.006,'sine');
  if(stage===3&&step%4===2)note(toneHz(-5,220),at,.22,.016,'triangle');
  step++;
 }
 function stopMusic(){
  if(timer!==null){clearInterval(timer);timer=null;}
 }
 function startMusic(){
  if(!musicOn||!startedByGesture||typeof document==='undefined'||document.hidden)return;
  if(!acquire()||timer!==null)return;
  nextBeat();
  timer=setInterval(nextBeat,stage===3?265:stage===2?310:370);
 }
 function unlock(){
  startedByGesture=true;
  acquire();
  startMusic();
 }
function sweep(start,end,duration,volume=0.04,wave='sawtooth'){
  if(!ctx||ctx.state==='closed')return;
  try{
   const now=ctx.currentTime+.008,o=ctx.createOscillator(),g=ctx.createGain();
   o.type=wave;o.frequency.setValueAtTime(start,now);
   o.frequency.exponentialRampToValueAtTime(Math.max(36,end),now+duration);
   g.gain.setValueAtTime(.0001,now);
   g.gain.exponentialRampToValueAtTime(volume,now+.025);
   g.gain.exponentialRampToValueAtTime(.0001,now+duration);
   o.connect(g);g.connect(ctx.destination);o.start(now);o.stop(now+duration+.02);
   o.onended=()=>{o.disconnect();g.disconnect();};
  }catch{}
 }
 function effect(kind){
  if(!effectOn)return;
  if(!startedByGesture)unlock();
  if(!acquire())return;
  const now=ctx.currentTime+.008;
  const tones={
   pick:[[540,.09,.029],[800,.10,.016]],
   place:[[370,.085,.035],[590,.12,.025]],
   invalid:[[175,.14,.031],[125,.11,.025]],
   clear:[[523,.13,.038],[659,.17,.035],[784,.20,.030],[1047,.26,.025]],
   undo:[[570,.10,.023],[420,.14,.020]],
   new:[[340,.12,.021],[455,.16,.018]]
  };
  if(kind==='rocket'){
   sweep(1100,155,.42,.06,'sawtooth');
   note(880,now,.17,.048,'triangle');note(1320,now+.10,.25,.036,'sine');return;
  }
  if(kind==='bomb'){
   sweep(210,44,.55,.092,'sawtooth');sweep(480,65,.28,.038,'triangle');
   note(62,now+.12,.33,.08,'triangle');return;
  }
  if(kind==='candy'){
   [740,988,1244,1480].forEach((f,i)=>note(f,now+i*.065,.20,.036,'sine'));return;
  }
  if(kind==='victory'){
   [523,659,784,1047,1318].forEach((f,i)=>note(f,now+i*.11,.42,.048,'triangle'));return;
  }
  if(kind==='gameover'){
   [330,262,196].forEach((f,i)=>note(f,now+i*.11,.24,.024,'triangle'));return;
  }
  const seq=tones[kind]||tones.place;
  seq.forEach(([hz,duration,vol],i)=>note(hz,now+i*.065,duration,vol,'sine'));
 }
 function setStage(n){stage=Number.isInteger(n)?Math.max(0,Math.min(3,n)):0;stopMusic();startMusic();}
 function setMusic(on){
  musicOn=!!on;
  stopMusic();
  if(musicOn)startMusic();
 }
 function setEffects(on){effectOn=!!on;}
 if(typeof document!=='undefined'){
  document.addEventListener('visibilitychange',()=>{
   if(document.hidden){stopMusic();if(ctx?.state==='running')void ctx.suspend().catch(()=>{});}
   else if(startedByGesture){void ctx?.resume().then(()=>startMusic()).catch(()=>{});}
  });
  window.addEventListener('pagehide',stopMusic);
 }
 return {unlock,effect,setMusic,setEffects,setStage,
  get musicEnabled(){return musicOn;},
  get effectsEnabled(){return effectOn;}
 };
}
