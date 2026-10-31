/* Geometry is deliberately independent from the DOM, so regressions can be
   caught in Node tests before shipping an Android APK. */
export function calculateBoardSize({
 cardHeight,cardWidth,paddingVertical=0,paddingHorizontal=0,gap=0,
 fixedHeights=[],borderVertical=0,margin=10,maxSize=475
}){
 const occupied=fixedHeights.reduce((sum,h)=>sum+Math.max(0,Number(h)||0),0);
 // Five children: scorebar, board, hint, tray, game controls = four flex gaps.
 const availableHeight=Math.max(0,cardHeight-paddingVertical-borderVertical-4*gap-occupied-margin);
 const availableWidth=Math.max(0,cardWidth-paddingHorizontal-margin);
 return Math.max(1,Math.floor(Math.min(maxSize,availableHeight,availableWidth)));
}
