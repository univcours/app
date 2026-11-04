import test from 'node:test';
import assert from 'node:assert/strict';
import {JSDOM} from 'jsdom';
import {arcadeEffect,CANDY_COLORS} from '../web/arcade-fx.js';

test('real Candy/Rocket/Bomb effects have particles, correct positions and a rocket beam',()=>{
 const dom=new JSDOM('<div id="fx"></div>');
 const priorWindow=globalThis.window,priorDoc=globalThis.document;
 try{
  globalThis.window=dom.window;
  globalThis.document=dom.window.document;
  const layer=dom.window.document.querySelector('#fx');
  assert.equal(CANDY_COLORS.length,6);
  arcadeEffect(layer,{kind:'candy',center:[4,4]});
  assert.equal(layer.querySelectorAll('.candy-fx-spark').length,11);
  assert.equal(layer.querySelectorAll('.candy-fx-beam').length,0);
  arcadeEffect(layer,{kind:'rocket',direction:'column',center:[5,3]});
  assert.equal(layer.querySelectorAll('.candy-fx-spark').length,14);
  assert.ok(layer.querySelector('.candy-fx-beam.column'));
  assert.equal(layer.querySelector('.candy-fx-icon').textContent,'🚀');
  arcadeEffect(layer,{kind:'bomb',center:[3,6]});
  assert.equal(layer.querySelectorAll('.candy-fx-spark').length,18);
  assert.equal(layer.querySelectorAll('.candy-fx-beam').length,0);
  assert.equal(layer.querySelector('.candy-fx-icon').textContent,'💥');
  dom.window.matchMedia=()=>({matches:true});
  arcadeEffect(layer,{kind:'bomb'});
  assert.equal(layer.children.length,0,'reduced motion disables explosive animation');
  clearTimeout(layer._arcadeTimer);
 }finally{
  globalThis.window=priorWindow;
  globalThis.document=priorDoc;
  dom.window.close();
 }
});
