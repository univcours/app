/* Side-by-side Android debug app: no effect on Play release / upload signature.
   Do not modify main applicationId, release buildType or signed AAB. */
import {existsSync,readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
export const DEBUG_SUFFIX='.candytest';
export const DEBUG_PACKAGE='com.novagrid.cosmicpuzzle.candytest';
export function addDebugSuffix(gradle){
 if(!/applicationId\s+['"]com\.novagrid\.cosmicpuzzle['"]/.test(gradle))
  throw Error('Wrong Play package, refusing to change Gradle');
 if(!/\bbuildTypes\s*\{/.test(gradle))throw Error('Missing Gradle buildTypes');
 if(/applicationIdSuffix\s+['"]\.candytest['"]/.test(gradle))return gradle;
 if(/\bdebug\s*\{/.test(gradle)){
  return gradle.replace(/\bdebug\s*\{/,m=>m+"\n          applicationIdSuffix '.candytest'");
 }
 return gradle.replace(/\bbuildTypes\s*\{/,m=>m+"\n        debug { applicationIdSuffix '.candytest' }");
}
export function setupDebug(root=resolve('android')){
 const cfg=JSON.parse(readFileSync('capacitor.config.json','utf8'));
 if(cfg.appId!=='com.novagrid.cosmicpuzzle'||cfg.appName!=='NovaGrid')
  throw Error('Unexpected app identity; refusing debug setup');
 const file=resolve(root,'app/build.gradle');
 if(!existsSync(file))throw Error('Native Gradle missing; run Capacitor sync first');
 const old=readFileSync(file,'utf8'),next=addDebugSuffix(old);
 if(next!==old)writeFileSync(file,next,'utf8');
 const dir=resolve(root,'app/src/debug/res/values');mkdirSync(dir,{recursive:true});
 const dest=resolve(dir,'strings.xml');
 if(existsSync(dest)&&!readFileSync(dest,'utf8').includes('NovaGrid Candy TEST'))
  throw Error('Existing custom debug resources found; refusing overwrite');
 writeFileSync(dest,'<?xml version="1.0" encoding="utf-8"?>\n'+
  '<resources><string name="app_name">NovaGrid Candy TEST</string>'+
  '<string name="title_activity_main">NovaGrid Candy TEST</string></resources>\n','utf8');
 console.log('[NovaGrid] Separate test-only Android package: '+DEBUG_PACKAGE);
}
if(process.argv[1]&&resolve(process.argv[1])===resolve('scripts/prepare-candy-debug.mjs'))setupDebug();
