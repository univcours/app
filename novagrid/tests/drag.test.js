import test from 'node:test';
import assert from 'node:assert/strict';
import {shapeDimensions,projectDragPoint,dragLift} from '../web/drag.js';
import {canPlace,emptyBoard} from '../web/engine.js';
const rect={left:15,top:100,width:360,height:360,right:375,bottom:460};
test('drag projection centers a single block over the proper cell',()=>{
 assert.deepEqual(projectDragPoint(15+5*40+20,100+3*40+20+80,rect,[[0,0]],80),{row:3,col:5});
});
test('multi-cell pieces are centered at target without losing their top-left anchor',()=>{
 const piece=[[0,0],[0,1],[1,0],[1,1]];
 assert.deepEqual(projectDragPoint(15+4*40,100+6*40+70,rect,piece,70),{row:5,col:3});
 assert.equal(canPlace(emptyBoard(),piece,5,3),true);
});
test('drag projection rejects a pointer outside board and invalid edge shapes',()=>{
 const p=[[0,0],[0,1],[0,2]];
 assert.equal(projectDragPoint(20,490,rect,p,70),null);
 const edge=projectDragPoint(374,240,rect,p,70);
 assert.ok(edge);assert.equal(canPlace(emptyBoard(),p,edge.row,edge.col),false);
});
test('drag geometry rejects nonexistent shapes and degenerate boards',()=>{
 assert.deepEqual(shapeDimensions([[0,1],[2,0]]),{rows:3,cols:2});
 assert.deepEqual(shapeDimensions(null),{rows:0,cols:0});
 assert.equal(projectDragPoint(100,120,rect,null),null);
 assert.equal(projectDragPoint(100,120,{...rect,width:0},[[0,0]]),null);
});
test('lift avoids covering blocks with the player finger',()=>{
 assert.equal(dragLift(20),54); assert.equal(dragLift(60),90);
});
