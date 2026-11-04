/* Side-by-side Android debug app: no effect on Play release / upload signature.
   Do not modify main applicationId, release buildType or signed AAB. */
import {existsSync,readFileSync,writeFileSync,mkdirSync,copyFileSync} from 'node:fs';
import {resolve} from 'node:path';
export const DEBUG_SUFFIX='.candytest';
export const DEBUG_PACKAGE='com.novagrid.cosmicpuzzle.candytest';
// Find direct Gradle blocks, ignoring comments and quoted strings.
// Groovy often defines signingConfigs.debug BEFORE buildTypes.debug.
// Mutating the first "debug {" corrupts the signing config and breaks Gradle.
function maskGradle(text){
 const out=Array.from(text),len=text.length;
 let state='code';
 for(let i=0;i<len;i++){
  const c=text[i],next=text[i+1];
  if(state==='code'){
   if(c==='/'&&next==='/'){out[i]=out[i+1]=' ';i++;state='line';continue;}
   if(c==='/'&&next==='*'){out[i]=out[i+1]=' ';i++;state='block';continue;}
   if(c==="'"||c==='"'){out[i]=' ';state=c;continue;}
  }else if(state==='line'){
   if(c==='\n'){state='code';continue;}
   out[i]=' ';continue;
  }else if(state==='block'){
   if(c==='*'&&next==='/'){out[i]=out[i+1]=' ';i++;state='code';continue;}
   if(c!=='\n'&&c!=='\r')out[i]=' ';
   continue;
  }else{
   if(c==='\\'){out[i]=' ';if(i+1<len){i++;out[i]=' ';}continue;}
   if(c===state){out[i]=' ';state='code';continue;}
   if(c!=='\n'&&c!=='\r')out[i]=' ';
   continue;
  }
 }
 return out.join('');
}
function closingBrace(masked,open){
 let depth=0;
 for(let i=open;i<masked.length;i++){
  if(masked[i]==='{')depth++;
  else if(masked[i]==='}'&&--depth===0)return i;
 }
 throw Error('Unbalanced Android Gradle braces; refusing change');
}
function directChild(masked,parent,name){
 let i=parent.open+1;
 while(i<parent.close){
  const m=/^[A-Za-z_][A-Za-z_0-9]*/.exec(masked.slice(i,parent.close));
  if(m){
   let j=i+m[0].length;
   while(j<parent.close&&/\s/.test(masked[j]))j++;
   if(masked[j]==='{'){
    const end=closingBrace(masked,j);
    if(end>parent.close)throw Error('Invalid nested Gradle block');
    if(m[0]===name)return {open:j,close:end};
    i=end+1;continue;
   }
   i=j>i?j:i+1;continue;
  }
  i++;
 }
 return null;
}
function gradleDebugBlock(text){
 const masked=maskGradle(text),root={open:-1,close:masked.length};
 const android=directChild(masked,root,'android');
 if(!android)throw Error('Missing top-level Android Gradle block');
 const buildTypes=directChild(masked,android,'buildTypes');
 if(!buildTypes)throw Error('Missing Android buildTypes block');
 return {masked,buildTypes,debug:directChild(masked,buildTypes,'debug')};
}
export function addDebugSuffix(gradle){
 if(!/applicationId\s+['"]com\.novagrid\.cosmicpuzzle['"]/.test(gradle))
  throw Error('Wrong Play package, refusing to change Gradle');
 let info=gradleDebugBlock(gradle);
 const suffix=/\bapplicationIdSuffix\s*(?:=\s*|\(\s*|\s+)(['"])([^'"]+)\1\s*\)?/g;
 const matches=[...gradle.matchAll(suffix)].filter(m=>info.masked.slice(m.index,m.index+'applicationIdSuffix'.length)==='applicationIdSuffix');
 let seenDebugSuffix=false;
 const edits=[];
 for(const m of matches){
  const inDebug=!!info.debug&&m.index>info.debug.open&&m.index<info.debug.close;
  if(inDebug){
   if(seenDebugSuffix){
    // Previous NovaGrid scripts repeatedly inserted applicationIdSuffix.
    // Keeping more than one would make the local build invalid. Remove
    // extra statements, preserving all other debug and release settings.
    edits.push({start:m.index,end:m.index+m[0].length,text:m[0].replace(/[^\r\n]/g,' ')});
   }else{
    seenDebugSuffix=true;
    // Migrate an older .originaltest/.beta/custom debug ID to the
    // explicitly requested Candy TEST ID. The original APK is separate.
    if(m[2]!==DEBUG_SUFFIX){
     const quoteStart=m[0].indexOf(m[1]+m[2]+m[1]);
     if(quoteStart<0)throw Error('Could not safely parse debug applicationIdSuffix');
     const start=m.index+quoteStart+1;
     edits.push({start,end:start+m[2].length,text:DEBUG_SUFFIX});
    }
   }
  }else if(m[2]===DEBUG_SUFFIX){
   // Fix the earlier bug which injected a suffix into signingConfigs or
   // the buildTypes root. Never change another release-specific suffix.
   edits.push({start:m.index,end:m.index+m[0].length,text:m[0].replace(/[^\r\n]/g,' ')});
  }
 }
 let cleaned=gradle;
 for(const edit of edits.sort((a,b)=>b.start-a.start)){
  cleaned=cleaned.slice(0,edit.start)+edit.text+cleaned.slice(edit.end);
 }
 if(seenDebugSuffix)return cleaned;
 info=gradleDebugBlock(cleaned);
 const insert=info.debug
  ?{at:info.debug.open+1,text:"\n            applicationIdSuffix '.candytest'\n"}
  :{at:info.buildTypes.open+1,text:"\n        debug { applicationIdSuffix '.candytest' }\n"};
 return cleaned.slice(0,insert.at)+insert.text+cleaned.slice(insert.at);
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
 if(next!==old){
  // Back up the full prior Gradle file once before replacing a legacy
  // debug suffix; the original release config always remains untouched.
  const gradleBackup=resolve(root,'app/novagrid-candy-prior-gradle.backup');
  if(!existsSync(gradleBackup))copyFileSync(file,gradleBackup);
  writeFileSync(file,next,'utf8');
 }
 if(!existsSync(dir))mkdirSync(dir,{recursive:true});
 if(!exists||before!==after)writeFileSync(dest,after,'utf8');
 console.log('[NovaGrid] Separate test-only Android package: '+DEBUG_PACKAGE);
}
if(process.argv[1]&&resolve(process.argv[1])===resolve('scripts/prepare-candy-debug.mjs'))setupDebug();
