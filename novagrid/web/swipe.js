/* Grid-distance-based swipe control for Blockfall, independent of pixel density.
   Converts an ongoing drag into cell steps without requiring finger release. */
export function createSwipeTracker(x,y,cellWidth,cellHeight){
 if(![x,y,cellWidth,cellHeight].every(Number.isFinite)||cellWidth<=0||cellHeight<=0)
  throw new RangeError('Invalid drag origin or cell dimensions');
 const stepX=Math.max(9,cellWidth*0.8);
 const stepY=Math.max(9,cellHeight*0.8);
 const startX=x,startY=y;
 let anchorX=x,anchorY=y,moved=false;
 function update(nextX,nextY){
  if(!Number.isFinite(nextX)||!Number.isFinite(nextY))
   return {horizontal:0,down:0,moved};
  if(Math.hypot(nextX-startX,nextY-startY)>9)moved=true;
  const horizontal=Math.max(-10,Math.min(10,Math.trunc((nextX-anchorX)/stepX)));
  const down=Math.min(18,Math.max(0,Math.floor((nextY-anchorY)/stepY)));
  anchorX+=horizontal*stepX;
  anchorY+=down*stepY;
  if(horizontal||down)moved=true;
  return {horizontal,down,moved};
 }
 return {update,get moved(){return moved;},get thresholds(){return {horizontal:stepX,vertical:stepY};}};
}
