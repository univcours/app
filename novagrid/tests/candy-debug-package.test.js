import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {addDebugSuffix,DEBUG_PACKAGE} from '../scripts/prepare-candy-debug.mjs';

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
