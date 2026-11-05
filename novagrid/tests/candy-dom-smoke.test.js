import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {JSDOM} from 'jsdom';

test('Endless NovaGrid boots directly, lets player move, and bonus game opens',async()=>{
 const html=readFileSync(new URL('../web/index.html',import.meta.url),'utf8');
 const dom=new JSDOM(html,{url:'https://novagrid.local/',pretendToBeVisual:true});
 const w=dom.window;
 for(const key of ['window','document','localStorage','navigator','HTMLElement','Event']){
  Object.defineProperty(globalThis,key,{configurable:true,value:key==='window'?w:w[key]});
 }
 Object.defineProperty(globalThis,'requestAnimationFrame',{configurable:true,value:cb=>w.setTimeout(cb,0)});
 Object.defineProperty(globalThis,'cancelAnimationFrame',{configurable:true,value:clearTimeout});
 Object.defineProperty(globalThis,'getComputedStyle',{configurable:true,value:w.getComputedStyle.bind(w)});
 try{
  await import('../web/app.js');
  assert.equal(w.document.querySelector('#galaxyOverlay'),null,'no stage map on launch');
  assert.equal(w.document.querySelector('#stageHud'),null,'no stage progress bar');
  assert.equal(w.document.querySelector('.mode.active')?.dataset.mode,'classic');
  assert.equal(w.document.querySelector('#intensityChip')?.textContent,'⚡ 1/9');
  assert.equal(w.document.querySelectorAll('#board .cell').length,81);
  const piece=w.document.querySelector('#pieces .piece:not([disabled])');
  assert.ok(piece,'gameplay must display a selectable shape');
  piece.dispatchEvent(new w.MouseEvent('click',{bubbles:true,detail:0}));
  const targets=[...w.document.querySelectorAll('#board .cell')];
  targets[0].click();
  assert.ok(Number(w.document.querySelector('#score').textContent.replace(/,/g,''))>0,'real placement updates score');
  assert.equal(w.document.querySelector('#stageProgressFill'),null);
  assert.ok(w.document.querySelector('#candyFxLayer'));
  const mode=[...w.document.querySelectorAll('[data-mode]')].find(x=>x.dataset.mode==='blockfall');
  assert.ok(mode);
  mode.click();
  assert.equal(w.document.querySelector('#blockfallOverlay').hidden,false);
  w.document.querySelector('#fallClose').click();
  assert.equal(w.document.querySelector('#blockfallOverlay').hidden,true);
 }finally{dom.window.close();}
});
