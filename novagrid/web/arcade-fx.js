/* Original, accessible Candy Arcade VFX. Pure DOM/CSS, no external assets.
   Repeated effects replace old nodes; capped particles, reduced-motion aware. */
export const CANDY_COLORS=['#ff5fa8','#ffad47','#ffe16b','#58e7a9','#55d5ff','#aa79ff'];
export function arcadeEffect(layer,event){
 if(!layer||!event)return;
 const reduce=typeof window!=='undefined'&&window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
 layer.replaceChildren();
 if(reduce)return;
 // Mobile boards have different dimensions: Classic 10x12, Blockfall 10x18.
 const cols=Math.max(1,Number(event.cols)||9),rows=Math.max(1,Number(event.rows)||9);
 const [row,col]=event.center||[rows*.5,cols*.5];
 const left=Math.max(0,Math.min(100,(col+.5)*100/cols));
 const top=Math.max(0,Math.min(100,(row+.5)*100/rows));
 const icon=document.createElement('span');icon.className='candy-fx-icon '+event.kind;
 icon.style.left=left+'%';icon.style.top=top+'%';
 icon.textContent=event.kind==='rocket'?'🚀':event.kind==='bomb'?'💥':'✦';
 layer.append(icon);
 const count=event.kind==='combo'?26:event.kind==='bomb'?18:event.kind==='rocket'?14:11;
 const size=event.kind==='combo'?Math.min(175,70+Number(event.groups||1)*30):event.kind==='bomb'?115:75;
 const frag=document.createDocumentFragment();
 for(let i=0;i<count;i++){
  const spark=document.createElement('i');spark.className='candy-fx-spark';
  spark.style.left=left+'%';spark.style.top=top+'%';
  spark.style.setProperty('--dx',Math.round(Math.cos(i*2*Math.PI/count)*size)+'px');
  spark.style.setProperty('--dy',Math.round(Math.sin(i*2*Math.PI/count)*size)+'px');
  spark.style.setProperty('--spark',CANDY_COLORS[i%CANDY_COLORS.length]);
  frag.append(spark);
 }
 layer.append(frag);
 if(event.kind==='combo'){
  const ring=document.createElement('span');ring.className='nova-combo-ring';layer.append(ring);
  const text=document.createElement('span');text.className='nova-combo-announce';
  const label=document.createElement('span');label.textContent='COMBO ×'+Math.max(1,Number(event.combo)||1)+'!';
  const bonus=document.createElement('small');bonus.textContent='+'+Math.max(0,Number(event.bonus)||0).toLocaleString();
  text.append(label,bonus);layer.append(text);
 }
 if(event.kind==='rocket'){
  const beam=document.createElement('span');
  beam.className='candy-fx-beam '+(event.direction||'row');
  beam.style.left=left+'%';beam.style.top=top+'%';
  layer.append(beam);
 }
 const previous=layer._arcadeTimer;
 if(previous)clearTimeout(previous);
 layer._arcadeTimer=setTimeout(()=>{layer.replaceChildren();layer._arcadeTimer=null;},1000);
}
