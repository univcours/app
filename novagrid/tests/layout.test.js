import test from 'node:test';
import assert from 'node:assert/strict';
import {calculateBoardSize} from '../web/layout.js';
test('board size subtracts scorebar and action buttons as well as tray and hint',()=>{
 const props={cardHeight:590,cardWidth:450,paddingVertical:20,paddingHorizontal:20,gap:7,
  fixedHeights:[44,21,75,38],margin:10};
 assert.equal(calculateBoardSize(props),590-20-7*4-(44+21+75+38)-10);
});
test('banner or stage HUD makes the card smaller and the board follows',()=>{
 const base={cardHeight:560,cardWidth:360,paddingVertical:20,paddingHorizontal:20,gap:7,fixedHeights:[44,21,75,38],margin:10};
 const ordinary=calculateBoardSize(base);
 const withAd=calculateBoardSize({...base,cardHeight:base.cardHeight-96});
 const withAdAndStage=calculateBoardSize({...base,cardHeight:base.cardHeight-96-38});
 assert.ok(withAd<ordinary);
 assert.ok(withAdAndStage<withAd);
 assert.ok(withAdAndStage+20+28+178+10<=base.cardHeight-96-38);
});
test('width never exceeds the available card width',()=>{
 const n=calculateBoardSize({cardHeight:1000,cardWidth:320,paddingHorizontal:24,fixedHeights:[42,20,74,36],gap:7});
 assert.equal(n,286);
});
test('handles very short viewport without negative dimensions',()=>{
 const n=calculateBoardSize({cardHeight:130,cardWidth:320,paddingVertical:24,fixedHeights:[40,25,70,40],gap:7});
 assert.equal(n,1);
});

import {readFileSync} from 'node:fs';
test('Blockfall is directly beside Classic and Daily in four top-level tabs',()=>{
 const html=readFileSync(new URL('../web/index.html',import.meta.url),'utf8');
 const tabs=[...html.matchAll(/data-mode="([^"]+)"/g)].map(m=>m[1]);
 assert.deepEqual(tabs,['classic','daily','blockfall','stage']);
 const css=readFileSync(new URL('../web/galaxy.css',import.meta.url),'utf8');
 assert.match(css,/grid-template-columns:repeat\(4,minmax\(0,1fr\)\)/);
});
test('Blockfall tab resumes saved or newest unlocked stage directly',()=>{
 const code=readFileSync(new URL('../web/app.js',import.meta.url),'utf8');
 assert.match(code,/btn\.dataset\.mode==='blockfall'/);
 assert.match(code,/nova\.blockfall\.lastLevel/);
 assert.match(code,/launchStage\(level\)/);
});
