/* Pure geometry for touch dragging. Normalized puzzle coordinates are top-left aligned. */
export function shapeDimensions(shape){
 if(!Array.isArray(shape)||!shape.length)return {rows:0,cols:0};
 return {rows:Math.max(...shape.map(p=>p[0]))+1,cols:Math.max(...shape.map(p=>p[1]))+1};
}
export function projectDragPoint(x,y,rect,shape,lift=0,size=9){
 const {rows,cols}=shapeDimensions(shape);
 if(!rows||!cols||!rect||rect.width<=0||rect.height<=0)return null;
 const centerX=x,centerY=y-lift;
 if(centerX<rect.left||centerY<rect.top||centerX>rect.right||centerY>rect.bottom)return null;
 const col=Math.round((centerX-rect.left)/(rect.width/size)-cols/2);
 const row=Math.round((centerY-rect.top)/(rect.height/size)-rows/2);
 return {row,col};
}
export function dragLift(cellSize){
 return Math.max(54,Math.min(90,cellSize*2.15));
}
