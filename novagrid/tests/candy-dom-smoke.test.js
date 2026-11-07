import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {JSDOM} from 'jsdom';

test('NovaGrid boots with two neon games, keeps its full-screen 10x12 grid and opens endless Blockfall',async()=>{
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
  const modes=[...w.document.querySelectorAll('.neon-duo-modes [data-mode]')];
  assert.deepEqual(modes.map(el=>el.dataset.mode),['classic','blockfall']);
  assert.equal(w.document.querySelectorAll('#board .cell').length,120);
  const piece=w.document.querySelector('#pieces .piece:not([disabled])');
  assert.ok(piece,'an initial puzzle piece is available');
  piece.dispatchEvent(new w.MouseEvent('click',{bubbles:true,detail:0}));
  const cells=[...w.document.querySelectorAll('#board .cell')];
  cells[0].click();
  assert.equal(Number(w.document.querySelector('#score').textContent.replace(/,/g,'')),0,'placement without a cleared line must never score');
  assert.ok(w.document.querySelectorAll('#board .cell.block').length>0,'the real piece was placed on the board');
  modes[1].click();
  const overlay=w.document.querySelector('#blockfallOverlay');
  assert.ok(overlay&&!overlay.hidden,'falling mode opens');
  assert.equal(w.document.querySelectorAll('#fallBoard .fall-cell').length,180);
  assert.match(w.document.querySelector('#fallStage').textContent,/Endless arcade/);
  assert.equal(w.document.querySelector('#fallResult').hidden,true);
  w.document.dispatchEvent(new w.KeyboardEvent('keydown',{bubbles:true,key:' '}));
  w.document.dispatchEvent(new w.KeyboardEvent('keydown',{bubbles:true,key:' '}));
  assert.equal(w.document.querySelector('#fallResult').hidden,true,'endless play does not stop after two pieces');
  w.document.querySelector('#fallClose').click();
  assert.equal(overlay.hidden,true);
  assert.equal(w.document.querySelectorAll('#board .cell').length,120,'10x12 puzzle remains available');
 }finally{dom.window.close();}
});
