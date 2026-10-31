import test from 'node:test';
import assert from 'node:assert/strict';
import {createSwipeTracker} from '../web/swipe.js';
test('horizontal movement updates continuously before pointer release',()=>{
 const track=createSwipeTracker(100,300,30,30);
 assert.equal(track.update(115,300).horizontal,0);
 assert.equal(track.update(125,300).horizontal,1);
 assert.equal(track.update(176,300).horizontal,2);
 assert.equal(track.update(150,300).horizontal,-1);
});
test('continuous downward drag makes multiple soft-drop steps without hard drop',()=>{
 const track=createSwipeTracker(80,100,25,28);
 assert.equal(track.update(80,116).down,0);
 assert.equal(track.update(80,150).down,2);
 assert.equal(track.update(80,200).down,2);
 assert.equal(track.update(80,260).down,3);
 assert.equal(track.update(80,120).down,0); // upward motion must not lift a piece
});
test('diagonal drag yields horizontal and downward actions in one move',()=>{
 const track=createSwipeTracker(100,100,30,30);
 assert.deepEqual(track.update(151,149),{horizontal:2,down:2,moved:true});
});
test('short stationary touch is a tap; tiny intentional movement suppresses rotation',()=>{
 const tap=createSwipeTracker(100,100,30,30);
 assert.equal(tap.update(104,104).moved,false);
 assert.equal(tap.moved,false);
 assert.equal(tap.update(111,100).moved,true);
});
test('large/invalid events remain bounded and robust',()=>{
 const track=createSwipeTracker(0,0,20,20);
 const moved=track.update(10000,10000);
 assert.deepEqual(moved,{horizontal:10,down:18,moved:true});
 assert.deepEqual(track.update(NaN,Infinity),{horizontal:0,down:0,moved:true});
 assert.throws(()=>createSwipeTracker(0,0,0,20),RangeError);
});
