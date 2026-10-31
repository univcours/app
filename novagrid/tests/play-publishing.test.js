import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read=relative=>readFileSync(new URL(relative,import.meta.url),'utf8');

test('NovaGrid title remains the one-word public app name',()=>{
 const cfg=JSON.parse(read('../capacitor.config.json'));
 assert.equal(cfg.appName,'NovaGrid');
 assert.equal(cfg.appId,'com.novagrid.cosmicpuzzle');
 const page=read('../web/index.html');
 assert.match(page,/<title>NovaGrid<\/title>/);
});

test('game has an accessible in-app privacy notice for Play review',()=>{
 const page=read('../web/index.html');
 const policy=read('../web/privacy.html');
 assert.match(page,/href="privacy.html"/);
 assert.match(policy,/Privacy Policy/);
 assert.match(policy,/Google AdMob/);
});

test('Play workflow checks target API and supports signing via encrypted secrets only',()=>{
 const ci=read('../../.github/workflows/novagrid-build.yml');
 assert.match(ci,/targetSdkVersion/);
 assert.match(ci,/NOVAGRID_UPLOAD_KEYSTORE_BASE64/);
 assert.match(ci,/jarsigner -verify/);
 assert.match(ci,/novagrid-play-internal-signed-aab/);
 assert.doesNotMatch(ci,/BEGIN PRIVATE KEY/);
});

test('Play Console upload is never triggered automatically or sent to production',()=>{
 const ci=read('../../.github/workflows/novagrid-build.yml');
 assert.match(ci,/publish_internal:/);
 assert.match(ci,/default: false/);
 assert.match(ci,/NOVAGRID_PLAY_SERVICE_ACCOUNT_JSON/);
 assert.match(ci,/github.event_name == 'workflow_dispatch' && inputs.publish_internal == true/);
 assert.match(ci,/tracks: internal/);
 assert.match(ci,/status: completed/);
 assert.doesNotMatch(ci,/tracks: production/);
});
test('Google Play version code changes with each Actions build',()=>{
 const ci=read('../../.github/workflows/novagrid-build.yml');
 assert.match(ci,/GITHUB_RUN_NUMBER/);
 assert.match(ci,/versionCode \$code/);
});
