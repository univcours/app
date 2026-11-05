/* Screenshot the REAL compiled game in headless Chrome (not an illustration).
 * Requires playwright-core and Chrome on the CI runner; never ships to the app.
 */
import {createServer} from 'node:http';
import {readFile,stat,mkdir} from 'node:fs/promises';
import {resolve,extname,join,normalize} from 'node:path';
import {pathToFileURL} from 'node:url';
const root=resolve('dist'),output=resolve('visual-qa/novagrid-actual-mobile.png');
const mime={'.html':'text/html','.js':'text/javascript','.css':'text/css','.svg':'image/svg+xml','.webp':'image/webp','.png':'image/png','.json':'application/json'};
const server=createServer(async(req,res)=>{
 try{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  const path=resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  if(!path.startsWith(root+'/')&&path!==root){res.writeHead(403).end();return;}
  const info=await stat(path);if(!info.isFile()){res.writeHead(404).end();return;}
  res.setHeader('Content-Type',(mime[extname(path)]||'application/octet-stream')+'; charset=utf-8');
  res.end(await readFile(path));
 }catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
try{
 const {chromium}=await import('playwright-core');
 const browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_PATH||'/usr/bin/google-chrome',args:['--no-sandbox','--disable-dev-shm-usage']});
 try{
  const context=await browser.newContext({viewport:{width:393,height:852},deviceScaleFactor:2,isMobile:true,hasTouch:true});
  const page=await context.newPage();
  const exceptions=[];page.on('pageerror',e=>exceptions.push(String(e)));
  await page.goto('http://127.0.0.1:'+server.address().port+'/',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('#board .cell',{timeout:12000});
  await page.evaluate(async()=>{
   // Use valid positions only. Repeated invalid clicks trigger a real Toast,
   // making the screenshot differ from normal gameplay.
   for(let move=0;move<16;move++){
    const score=()=>Number((document.querySelector('#score')?.textContent||'0').replaceAll(',',''));
    let played=false;
    const cells=[...document.querySelectorAll('#board .cell')];
    const rows=12,cols=10;
    for(const piece of document.querySelectorAll('#pieces .piece:not([disabled])')){
     const grid=piece.querySelector('.piecegrid');
     const width=Number(grid?.style.gridTemplateColumns.match(/repeat\((\d+),/)?.[1]);
     if(!width)continue;
     const shape=[...grid.children].flatMap((cell,i)=>cell.classList.contains('blank')?[]:[[Math.floor(i/width),i%width]]);
     if(!shape.length)continue;
     for(let r=0;r<rows&&!played;r++)for(let col=0;col<cols&&!played;col++){
      const valid=shape.every(([dr,dc])=>r+dr<rows&&col+dc<cols&&!cells[(r+dr)*cols+col+dc]?.classList.contains('block'));
      if(!valid)continue;
      piece.dispatchEvent(new MouseEvent('click',{bubbles:true,detail:0}));
      const old=score();cells[r*cols+col].click();
      if(score()>old)played=true;
     }
     if(played)break;
    }
    if(!played||document.querySelector('#dialog')?.hidden===false)break;
   }
  });
  await page.waitForTimeout(500);
  await mkdir(resolve('visual-qa'),{recursive:true});
  await page.screenshot({path:output,fullPage:false});
  const board=await page.locator('#board').boundingBox();
  const actual=await page.evaluate(()=>({score:document.querySelector('#score')?.textContent,
   filled:document.querySelectorAll('#board .cell.block').length,
   board:document.querySelector('#board')?.getBoundingClientRect().width,
   gameModes:[...document.querySelectorAll('[data-mode]')].map(x=>x.dataset.mode)}));
  console.log(JSON.stringify({output,board,actual,pageErrors:exceptions},null,2));
  if(exceptions.length)throw Error('Mobile page exception: '+exceptions.join(' | '));
  if(!board||board.width<300)throw Error('Playfield too small in 393 px portrait: '+board?.width);
  if(actual.filled===0)throw Error('Failed to play any block into the actual grid.');
  if(actual.gameModes.join(',')!=='classic,blockfall')throw Error('Unexpected game modes');
  // Screenshot and assert the second playable mode, not a promotional mockup.
  await page.locator('[data-mode="blockfall"]').click();
  await page.waitForSelector('#blockfallOverlay:not([hidden]) #fallBoard .fall-cell',{timeout:10000});
  // Build a real colorful stack for review without changing game physics.
  await page.evaluate(()=>{
   const press=key=>document.dispatchEvent(new KeyboardEvent('keydown',{bubbles:true,cancelable:true,key}));
   for(let turn=0;turn<12;turn++){
    const shifts=turn%4;
    const side=turn%2===0?'ArrowLeft':'ArrowRight';
    for(let i=0;i<shifts;i++)press(side);
    press(' ');
    if(!document.querySelector('#fallResult')?.hidden)break;
   }
  });
  await page.waitForTimeout(250);
  const fallCells=await page.locator('#fallBoard .fall-cell').count();
  const fallRect=await page.locator('#fallBoard').boundingBox();
  const blockfallPath=resolve('visual-qa/novagrid-blockfall-actual.png');
  await page.screenshot({path:blockfallPath,fullPage:false});
  console.log(JSON.stringify({blockfallPath,fallCells,fallRect},null,2));
  if(fallCells!==180||!fallRect||fallRect.width<195)throw Error('Blockfall visual layout is broken');
  await context.close();
 }finally{await browser.close();}
}finally{await new Promise(r=>server.close(r));}
