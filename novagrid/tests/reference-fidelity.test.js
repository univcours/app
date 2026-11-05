import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {advanceFever,FEVER_DURATION} from '../web/fever.js';
const read=p=>readFileSync(new URL(p,import.meta.url),'utf8');

test('Fever charges from real line clears, not from ad views or idle play',()=>{
 const start=advanceFever({},0,0,8);
 assert.equal(start.fever,0);
 const once=advanceFever(start,1,1,40);
 assert.equal(once.fever,37);
 const twice=advanceFever(once,2,2,80);
 assert.equal(twice.activated,true);
 assert.equal(twice.feverTurns,FEVER_DURATION);
 assert.equal(twice.bonus,0);
});
test('Fever bonus lasts five earned gameplay moves, then resets',()=>{
 let state={fever:100,feverTurns:5};
 let bonuses=0;
 for(let i=0;i<5;i++){
  state=advanceFever(state,1,3,50);bonuses+=state.bonus;
 }
 assert.equal(bonuses,250);assert.equal(state.fever,0);assert.equal(state.feverTurns,0);
 const later=advanceFever(state,0,0,50);assert.equal(later.bonus,0);
});
test('user cosmic reference has central combo FX and glass pieces, not a flat color wash',()=>{
 const fx=read('../web/arcade-fx.js'),html=read('../web/index.html'),css=read('../web/cosmic-reference.css');
 assert.match(fx,/nova-combo-announce/);assert.match(fx,/nova-combo-ring/);
 assert.match(html,/id="pauseMain"/);assert.match(html,/id="novaFeverFill"/);
 assert.match(css,/\.board \.cell\.block::after/);
 assert.match(css,/\.nova-sky \.nova-planet/);
 assert.match(css,/\.fall-cell\.fall-filled/);
 assert.match(css,/prefers-reduced-motion/);
 assert.match(read('../web/app.js'),/arcadeEffect\(\$\('candyFxLayer'\),\{kind:'combo'/);
});
