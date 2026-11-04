import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {addDebugSuffix,mergeDebugStrings,setupDebug,DEBUG_PACKAGE} from '../scripts/prepare-candy-debug.mjs';

test('Candy test variant stays fully separate from Play-signed NovaGrid',()=>{
 const generated=[
  'android {',
  " defaultConfig { applicationId 'com.novagrid.cosmicpuzzle' }",
  " buildTypes { release { minifyEnabled false } }",
  '}'
 ].join('\n');
 const out=addDebugSuffix(generated);
 assert.equal(DEBUG_PACKAGE,'com.novagrid.cosmicpuzzle.candytest');
 assert.match(out,/debug \{ applicationIdSuffix '\.candytest' \}/);
 assert.match(out,/release \{ minifyEnabled false \}/);
 assert.match(out,/applicationId 'com\.novagrid\.cosmicpuzzle'/);
 assert.equal(addDebugSuffix(out),out);
 assert.throws(()=>addDebugSuffix(out.replace("applicationId 'com.novagrid.cosmicpuzzle'","applicationId 'wrong.package'")),/Wrong Play package/);
});
test('Only the debug APK is separated, production branch remains one NovaGrid original',()=>{
 const packageJson=JSON.parse(readFileSync(new URL('../package.json',import.meta.url),'utf8'));
 assert.match(packageJson.scripts['android:sync'],/prepare-candy-debug\.mjs/);
 const workflow=readFileSync(new URL('../../.github/workflows/novagrid-build.yml',import.meta.url),'utf8');
 assert.match(workflow,/branches: \[novagrid-original-1-0-0\]/);
 assert.match(workflow,/node scripts\/prepare-candy-debug\.mjs/);
 assert.match(workflow,/tracks: internal/);
 assert.doesNotMatch(workflow,/tracks: production/);
});

test('existing debug strings are merged without removing any custom Android resources',()=>{
 const xml='<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'+
  ' <string name="app_name">NovaGrid</string>\n'+
  ' <string name="title_activity_main">Old Name</string>\n'+
  ' <string name="other_setting" translatable="false">Keep &amp; Preserve</string>\n'+
  '</resources>\n';
 const merged=mergeDebugStrings(xml);
 assert.match(merged,/<string name="app_name">NovaGrid Candy TEST<\/string>/);
 assert.match(merged,/<string name="title_activity_main">NovaGrid Candy TEST<\/string>/);
 assert.ok(merged.includes('<string name="other_setting" translatable="false">Keep &amp; Preserve</string>'));
 assert.equal(mergeDebugStrings(merged),merged,'repeated Android sync must be idempotent');
 assert.equal((merged.match(/name="app_name"/g)||[]).length,1,'no duplicate launcher resources');
});
test('missing launcher names are added while preserving unrelated resources',()=>{
 const xml='<resources>\n <string name="custom">Keep me</string>\n</resources>\n';
 const merged=mergeDebugStrings(xml);
 assert.ok(merged.includes('name="custom">Keep me</string>'));
 assert.ok(merged.includes('name="app_name">NovaGrid Candy TEST</string>'));
 assert.ok(merged.includes('name="title_activity_main">NovaGrid Candy TEST</string>'));
 assert.equal(mergeDebugStrings(merged),merged);
});
test('malformed or ambiguous resources are never overwritten',()=>{
 assert.throws(()=>mergeDebugStrings('<invalid/>'),/not a normal Android resources XML/);
 assert.throws(()=>mergeDebugStrings('<resources><string name="app_name">A</string><string name="app_name">B</string></resources>'),/Ambiguous debug string resource/);
 assert.throws(()=>mergeDebugStrings('<resources><string name="app_name" /></resources>'),/Ambiguous debug string resource/);
});
test('real setup on pre-existing debug resources succeeds, backs up once, stays idempotent and changes only debug Gradle',()=>{
 const dir=mkdtempSync(join(tmpdir(),'novagrid-candy-resource-'));
 const cwd=process.cwd();
 try{
  const values=join(dir,'android','app','src','debug','res','values');
  mkdirSync(values,{recursive:true});
  writeFileSync(join(dir,'capacitor.config.json'),JSON.stringify({appId:'com.novagrid.cosmicpuzzle',appName:'NovaGrid'}));
  const gradle=join(dir,'android','app','build.gradle');
  writeFileSync(gradle,"android { defaultConfig { applicationId 'com.novagrid.cosmicpuzzle' } buildTypes { release { minifyEnabled false } } }");
  const old='<?xml version="1.0" encoding="utf-8"?>\n<resources>\n<string name="app_name">NovaGrid</string>\n<string name="title_activity_main">NovaGrid</string>\n<string name="other_resource">Original</string>\n</resources>\n';
  writeFileSync(join(values,'strings.xml'),old);
  process.chdir(dir);
  setupDebug(join(dir,'android'));
  const updated=readFileSync(join(values,'strings.xml'),'utf8');
  assert.ok(updated.includes('name="other_resource">Original</string>'));
  assert.equal((updated.match(/NovaGrid Candy TEST/g)||[]).length,2);
  const backup=join(dir,'android','app','novagrid-candy-debug-strings.original.backup');
  assert.equal(existsSync(backup),true);
  assert.equal(readFileSync(backup,'utf8'),old);
  setupDebug(join(dir,'android'));
  assert.equal(readFileSync(join(values,'strings.xml'),'utf8'),updated);
  assert.equal(readFileSync(backup,'utf8'),old);
  assert.match(readFileSync(gradle,'utf8'),/debug \{ applicationIdSuffix '\.candytest' \}/);
 }finally{
  process.chdir(cwd);
  rmSync(dir,{recursive:true,force:true});
 }
});

test('signingConfigs.debug before buildTypes.debug does not steal applicationIdSuffix',()=>{
 const input=[
  'plugins { id "com.android.application" }',
  'android {',
  " defaultConfig { applicationId 'com.novagrid.cosmicpuzzle' }",
  ' signingConfigs {',
  "  debug { storeFile file('debug.keystore') }",
  ' }',
  " buildTypes { release { minifyEnabled false } debug { debuggable true } }",
  '}'
 ].join('\n');
 const result=addDebugSuffix(input);
 assert.match(result,/signingConfigs \{\s*debug \{ storeFile file\('debug.keystore'\) \}\s*\}/);
 assert.match(result,/buildTypes \{ release \{ minifyEnabled false \} debug \{\s*applicationIdSuffix '\.candytest'/);
 assert.equal((result.match(/applicationIdSuffix/g)||[]).length,1);
 assert.equal(addDebugSuffix(result),result);
});
test('repairs exact misplaced Candy suffix in signingConfigs and builds debug block correctly',()=>{
 const input=[
  'android {',
  " defaultConfig { applicationId 'com.novagrid.cosmicpuzzle' }",
  ' signingConfigs { debug {',
  "   applicationIdSuffix '.candytest'",
  "   storeFile file('debug.keystore')",
  ' }}',
  ' buildTypes { release { minifyEnabled false } }',
  '}'
 ].join('\n');
 const fixed=addDebugSuffix(input);
 const signing=fixed.slice(fixed.indexOf('signingConfigs'),fixed.indexOf('buildTypes'));
 assert.doesNotMatch(signing,/applicationIdSuffix/);
 assert.match(signing,/storeFile file\('debug.keystore'\)/);
 assert.match(fixed,/buildTypes \{\s*debug \{ applicationIdSuffix '\.candytest' \}/);
 assert.equal(addDebugSuffix(fixed),fixed);
});
test('repairs misplaced Candy suffix directly under buildTypes without touching release block',()=>{
 const input=[
  'android {',
  " defaultConfig { applicationId 'com.novagrid.cosmicpuzzle' }",
  ' buildTypes {',
  "   applicationIdSuffix '.candytest'",
  "   release { proguardFiles getDefaultProguardFile('proguard-android-optimize.txt') }",
  ' }',
  '}'
 ].join('\n');
 const fixed=addDebugSuffix(input);
 assert.match(fixed,/buildTypes \{\s*debug \{ applicationIdSuffix '\.candytest' \}/);
 assert.match(fixed,/release \{ proguardFiles getDefaultProguardFile\('proguard-android-optimize.txt'\) \}/);
 assert.equal((fixed.match(/applicationIdSuffix/g)||[]).length,1);
});
test('preserves a deliberately configured non-Candy debug suffix and refuses to override it',()=>{
 const input="android { defaultConfig { applicationId 'com.novagrid.cosmicpuzzle' } buildTypes { debug { applicationIdSuffix '.another' } release {} } }";
 assert.throws(()=>addDebugSuffix(input),/Existing custom debug applicationIdSuffix/);
});
