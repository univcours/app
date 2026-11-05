import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {AD_POLICY,getAdsStatus} from '../web/ads.js';
test('Interstitial and voluntary Rewarded are enabled but banners remain disabled',()=>{
 assert.equal(AD_POLICY.banner,false);
 assert.equal(AD_POLICY.interstitial,true);
 assert.equal(AD_POLICY.rewarded,true);
 assert.equal(AD_POLICY.rewardedInterstitial,false);
 assert.match(getAdsStatus().banner,/disabled/);
});
test('native AdMob bridge does not request banner but retains interstitial',()=>{
 const code=readFileSync(new URL('../web/ads.js',import.meta.url),'utf8');
 assert.doesNotMatch(code,/AdMob\.showBanner\s*\(/);
 assert.match(code,/AdMob\.removeBanner\s*\(/);
 assert.match(code,/ad\.prepareInterstitial\s*\(/);
 assert.match(code,/ad\.showInterstitial\s*\(/);
});
test('fullscreen stylesheet respects Android status and navigation bars',()=>{
 const css=readFileSync(new URL('../web/no-banner.css',import.meta.url),'utf8');
 assert.match(css,/html\.no-banner\s+#gameShell/);
 assert.match(css,/--safe-area-inset-top/);
 assert.match(css,/--safe-area-inset-bottom/);
});
