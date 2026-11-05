import test from 'node:test';import assert from 'node:assert/strict';
import {recordFinished,normalizeStats} from '../web/player-stats.js';
import {readFileSync} from 'node:fs';
test('local player stats use actual completed games and cannot invent world ranking',()=>{
 const s=recordFinished(null,{mode:'classic',score:450,moves:40,combo:3,clears:8,intensity:3});
 assert.equal(s.games,1);assert.equal(s.highest,450);assert.equal(s.bestIntensity,3);
 const t=recordFinished(s,{mode:'falling',score:110,drops:8,combo:2,lines:1,intensity:2});
 assert.equal(t.games,2);assert.equal(t.totalScore,560);assert.equal(t.history.length,2);
 assert.equal(t.history[1].mode,'blockfall');
 assert.equal(normalizeStats({games:-99}).games,0);
});
test('UI includes no paid checkout or fake world leaderboard, and shows mini controls',()=>{
 const html=readFileSync(new URL('../web/index.html',import.meta.url),'utf8');
 const script=readFileSync(new URL('../web/app.js',import.meta.url),'utf8');
 const ads=readFileSync(new URL('../web/ads.js',import.meta.url),'utf8');
 assert.match(html,/id="shopOpen"/);assert.match(html,/id="statsOpen"/);assert.match(html,/id="shieldBtn"/);
 assert.doesNotMatch(html,/data-mode="daily"|data-mode="stage"|id="stageHud"/);
 assert.doesNotMatch(script,/createGalaxyUI|startStage\(/);
 assert.doesNotMatch(ads,/AdMob\.showBanner\s*\(/);
 assert.match(ads,/Number\(reward\.amount\)>0/);
});
