import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {JSDOM} from 'jsdom';
import {AD_POLICY,getAdsStatus,setBannerDock} from '../web/ads.js';
const read=path=>readFileSync(new URL(path,import.meta.url),'utf8');

test('anchored banner is enabled as a separate pane, while interstitial stays at natural replay breaks',()=>{
 assert.equal(AD_POLICY.banner,true);
 assert.equal(AD_POLICY.interstitial,true);
 assert.equal(AD_POLICY.rewarded,false);
 assert.equal(AD_POLICY.rewardedInterstitial,false);
 assert.match(getAdsStatus().banner,/not requested|loading|loaded/);
 const code=read('../web/ads.js');
 assert.match(code,/AdMob\.showBanner\s*\(/);
 assert.match(code,/BannerAdSize\.ADAPTIVE_BANNER/);
 assert.match(code,/BannerAdPosition\.BOTTOM_CENTER/);
 assert.match(code,/BannerAdPluginEvents\.SizeChanged/);
 assert.match(code,/BannerAdPluginEvents\.FailedToLoad/);
 assert.match(code,/consent\.canRequestAds/);
 assert.match(code,/ad\.prepareInterstitial\s*\(/);
 assert.match(code,/ad\.showInterstitial\s*\(/);
});
test('live build accepts only owner-supplied banner unit; local beta uses Google test unit',()=>{
 const build=read('../scripts/build.mjs');
 assert.match(build,/ADMOB_BANNER_UNIT_ID/);
 assert.match(build,/bannerId:banner\|\|null/);
 assert.match(build,/ca-app-pub-3940256099942544\/9214589741/);
});
test('the real game window stays ABOVE separate native ad dock',()=>{
 const html=read('../web/index.html');
 const css=read('../web/banner-dock.css');
 const first=html.indexOf('id="gameShell"');
 const last=html.indexOf('</main>');
 const dock=html.indexOf('id="novaBannerDock"');
 assert.ok(first<last&&last<dock&&dock>0,'dock is a sibling below the game, not inside it');
 assert.match(html,/banner-dock\.css/);
 assert.match(css,/bottom:calc\(var\(--native-ad-reserve,64px\)/);
 assert.match(css,/html\.native-ad-layout \.blockfall-overlay/);
 assert.match(css,/border-top:2px solid/);
 assert.match(css,/pointer-events:none/);
});
test('bottom banner dock reserves measured native ad height and disappears on failure/consent block',()=>{
 const dom=new JSDOM(read('../web/index.html'),{url:'https://novagrid.test/'});
 const oldDoc=globalThis.document,oldEvent=globalThis.Event;
 globalThis.document=dom.window.document;globalThis.Event=dom.window.Event;
 try{
  const dock=document.getElementById('novaBannerDock');
  setBannerDock(true,52);
  assert.equal(document.documentElement.classList.contains('native-ad-layout'),true);
  assert.equal(dock.hidden,false);
  assert.equal(document.documentElement.style.getPropertyValue('--native-ad-reserve'),'64px');
  setBannerDock(true,88);
  assert.equal(document.documentElement.style.getPropertyValue('--native-ad-reserve'),'100px');
  setBannerDock(false);
  assert.equal(dock.hidden,true);
  assert.equal(document.documentElement.classList.contains('no-banner'),true);
  assert.equal(document.documentElement.style.getPropertyValue('--native-ad-reserve'),'0px');
 }finally{
  if(oldDoc===undefined)delete globalThis.document;else globalThis.document=oldDoc;
  if(oldEvent===undefined)delete globalThis.Event;else globalThis.Event=oldEvent;
  dom.window.close();
 }
});
