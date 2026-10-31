import test from 'node:test';
import assert from 'node:assert/strict';
import {musicPhrase,toneHz,createGameAudio} from '../web/audio.js';
test('original ambient phrase contains bounded note offsets',()=>{
 assert.equal(musicPhrase.length,16);
 assert.ok(musicPhrase.every(n=>Number.isInteger(n)&&n>=0&&n<=24));
});
test('pitch frequencies are monotonic and have standard octave ratio',()=>{
 assert.equal(toneHz(0),220);
 assert.ok(Math.abs(toneHz(12)-440)<0.000001);
 assert.ok(toneHz(10)>toneHz(7));
});
test('audio controller is safe to use without a browser or audio device',()=>{
 const audio=createGameAudio({effectsEnabled:false,musicEnabled:false});
 assert.equal(audio.musicEnabled,false);
 audio.unlock();audio.effect('pick');audio.setMusic(true);audio.setEffects(true);
 assert.equal(audio.effectsEnabled,true);assert.equal(audio.musicEnabled,true);
});
