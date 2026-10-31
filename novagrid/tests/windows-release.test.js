import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const read = path => readFileSync(new URL(path,import.meta.url),'utf8');

test('every Android sync fixes the launcher name NovaGrid, not its old title',()=>{
 const packageJson=JSON.parse(read('../package.json'));
 const sync=packageJson.scripts['android:sync'];
 assert.match(sync,/npm run android:name/);
 assert.ok(sync.indexOf('npx cap sync android')<sync.indexOf('npm run android:name'));
 assert.equal(JSON.parse(read('../capacitor.config.json')).appName,'NovaGrid');
});
test('one-command Windows update verifies name and installs without deleting data',()=>{
 const script=read('../scripts/update-build-install.ps1');
 assert.match(script,/npm\.cmd.*android:sync/);
 assert.match(script,/app_name/);
 assert.match(script,/title_activity_main/);
 assert.match(script,/gradlew\.bat/);
 assert.match(script,/adb install -r \$apk/);
 assert.doesNotMatch(script,/adb uninstall|reset --hard|git clean|pm clear/);
});
test('release signing does not store keys in the repository',()=>{
 const script=read('../scripts/update-build-install.ps1');
 assert.match(script,/NOVAGRID_UPLOAD_KEYSTORE_PATH/);
 assert.match(script,/-storepass:env/);
 assert.match(script,/jarsigner\.exe/);
});

test('PowerShell release script auto-detects Android Studio bundled Java on Windows',()=>{
 const script=read('../scripts/update-build-install.ps1');
 assert.match(script,/function Enable-AndroidStudioJava/);
 assert.match(script,/Android\\Android Studio\\jbr/);
 assert.match(script,/bin\\java\.exe/);
 assert.match(script,/bin\\javac\.exe/);
 assert.match(script,/\$env:JAVA_HOME =/);
 assert.match(script,/Enable-AndroidStudioJava\s*\n\s*Write-Host '\[NovaGrid\] Build APK/);
});
