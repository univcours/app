import test from 'node:test';
import assert from 'node:assert/strict';
import {renameAndroidStrings,DISPLAY_NAME} from '../scripts/set-android-app-name.mjs';
import {readFileSync} from 'node:fs';
test('Capacitor-generated Android app name and task switcher show NovaGrid only',()=>{
 const xml='<resources><string name="app_name">NovaGrid: Cosmic Puzzle</string>'+
 '<string name="title_activity_main">NovaGrid: Cosmic Puzzle</string>'+
 '<string name="package_name">com.novagrid.cosmicpuzzle</string></resources>';
 const renamed=renameAndroidStrings(xml);
 assert.equal(DISPLAY_NAME,'NovaGrid');
 assert.match(renamed,/<string name="app_name">NovaGrid<\/string>/);
 assert.match(renamed,/<string name="title_activity_main">NovaGrid<\/string>/);
 assert.match(renamed,/<string name="package_name">com.novagrid.cosmicpuzzle<\/string>/);
 assert.equal(renameAndroidStrings(renamed),renamed);
});
test('fails safely if Android string resource names change',()=>{
 assert.throws(()=>renameAndroidStrings('<resources><string name="app_name">Other</string></resources>'),/Expected/);
});
test('Capacitor and web display name both match NovaGrid',()=>{
 const cfg=JSON.parse(readFileSync(new URL('../capacitor.config.json',import.meta.url),'utf8'));
 const html=readFileSync(new URL('../web/index.html',import.meta.url),'utf8');
 assert.equal(cfg.appName,'NovaGrid');
 assert.match(html,/<title>NovaGrid<\/title>/);
 assert.match(html,/<div class="brand">NovaGrid<\/div>/);
});
