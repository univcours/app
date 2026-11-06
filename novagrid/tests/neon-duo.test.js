import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {makeFallingState,fallingConfig,hardDropFalling} from '../web/falling.js';
const read=path=>readFileSync(new URL(path,import.meta.url),'utf8');

test('Block Puzzle and Blockfall share a neon glass style above an isolated banner dock',()=>{
 const html=read('../web/index.html'),css=read('../web/neon-duo.css');
 assert.deepEqual([...html.matchAll(/data-mode="([^"]+)"/g)].map(x=>x[1]),['classic','blockfall']);
 assert.match(html,/href="neon-duo\.css"/);
 assert.match(css,/\.board \.cell\.block/);
 assert.match(css,/\.fall-cell\.fall-filled/);
 assert.match(css,/\.neon-duo-modes/);
 assert.match(css,/@keyframes nova-nebula-drift/);
 assert.match(css,/@media\(prefers-reduced-motion:reduce\)/);
 assert.match(read('../web/ads.js'),/banner:true/);
 assert.ok(read('../web/banner-dock.css').includes('html.native-ad-layout .blockfall-overlay'));
});
test('Tetris-style Blockfall is a full-length run, never a one-line stage',()=>{
 const ui=read('../web/falling-ui.js');
 const app=read('../web/app.js');
 assert.match(app,/falling\?\.open\(12001,\{endless:true\}\)/);
 assert.match(ui,/goal:Number\.MAX_SAFE_INTEGER/);
 assert.match(ui,/nova\.blockfall\.endless\.v1/);
 assert.match(ui,/fallFeverFill/);
 const config={...fallingConfig(12001),kind:'score',goal:Number.MAX_SAFE_INTEGER};
 let state=makeFallingState(12001);
 for(let i=0;i<3;i++){
  state=hardDropFalling(state,config);
  assert.equal(state.over,false,'should not stop at early objective');
  assert.equal(state.won,false);
 }
 assert.equal(state.drops,3);
});
test('production 1.0 package and test app IDs stay separate',()=>{
 const config=JSON.parse(read('../capacitor.config.json'));
 const build=read('../scripts/prepare-candy-debug.mjs');
 assert.equal(config.appId,'com.novagrid.cosmicpuzzle');
 assert.match(build,/com\.novagrid\.cosmicpuzzle\.candytest/);
});


test('Blockfall gives no fake line-clear bonus for simply dropping a piece',()=>{
 const config={...fallingConfig(12001),goal:Number.MAX_SAFE_INTEGER};
 const start=makeFallingState(12001);
 const after=hardDropFalling(start,config);
 assert.equal(after.lines,0);
 assert.ok(after.score<100, 'a non-clearing first drop must not earn 1200 points: '+after.score);
});
