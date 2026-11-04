/* Side-by-side Android debug app: no effect on Play release / upload signature.
   Do not modify main applicationId, release buildType or signed AAB. */
import {existsSync,readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
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
// Preserve other Android debug resources, including pre-existing launcher strings.
export function mergeDebugStrings(xml){
 if(typeof xml!=='string'||!/<resources(?:\s[^>]*)?>/.test(xml)||!/<\/resources\s*>/.test(xml))
  throw Error('Existing debug strings.xml is not a normal Android resources XML; refusing to modify it');
 let result=xml;
 for(const name of ['app_name','title_activity_main']){
  const matches=[...result.matchAll(/<string\b[^>]*>[\s\S]*?<\/string\s*>/g)]
   .map(m=>m[0]).filter(tag=>{
    const attr=tag.match(/\bname\s*=\s*(["'])([^"']+)\1/);
    return attr?.[2]===name;
   });
  const selfClosing=[...result.matchAll(/<string\b[^>]*\/>/g)].some(m=>{
   const attr=m[0].match(/\bname\s*=\s*(["'])([^"']+)\1/);
   return attr?.[2]===name;
  });
  if(matches.length>1||selfClosing)
   throw Error('Ambiguous debug string resource: '+name+'; refusing to overwrite');
  if(matches.length===1){
   const source=matches[0];
   const updated=source.replace(/(>)[\s\S]*?(<\/string\s*>)/,'$1NovaGrid Candy TEST$2');
   result=result.replace(source,updated);
  }else{
   result=result.replace(/<\/resources\s*>/,'  <string name="'+name+'">NovaGrid Candy TEST</string>\n</resources>');
  }
 }
 return result;
}
export function setupDebug(root=resolve('android')){
 const cfg=JSON.parse(readFileSync('capacitor.config.json','utf8'));
 if(cfg.appId!=='com.novagrid.cosmicpuzzle'||cfg.appName!=='NovaGrid')
  throw Error('Unexpected app identity; refusing debug setup');
 const file=resolve(root,'app/build.gradle');
 if(!existsSync(file))throw Error('Native Gradle missing; run Capacitor sync first');
 const old=readFileSync(file,'utf8'),next=addDebugSuffix(old);
 const dir=resolve(root,'app/src/debug/res/values');
 const dest=resolve(dir,'strings.xml'),exists=existsSync(dest);
 const before=exists?readFileSync(dest,'utf8'):'<?xml version="1.0" encoding="utf-8"?>\n<resources>\n</resources>\n';
 // Validate ALL resources before writing Gradle or the debug overlay.
 const after=mergeDebugStrings(before);
 if(exists&&before!==after){
  const backup=resolve(root,'app/novagrid-candy-debug-strings.original.backup');
  if(!existsSync(backup))copyFileSync(dest,backup);
 }
 if(next!==old)writeFileSync(file,next,'utf8');
 if(!existsSync(dir))mkdirSync(dir,{recursive:true});
 if(!exists||before!==after)writeFileSync(dest,after,'utf8');
 console.log('[NovaGrid] Separate test-only Android package: '+DEBUG_PACKAGE);
}
if(process.argv[1]&&resolve(process.argv[1])===resolve('scripts/prepare-candy-debug.mjs'))setupDebug();
