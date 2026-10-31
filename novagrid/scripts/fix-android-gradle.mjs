import {existsSync,readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const legacy=/getDefaultProguardFile\(\s*(['"])proguard-android\.txt\1\s*\)/g;
const modern=/getDefaultProguardFile\(\s*(['"])proguard-android-optimize\.txt\1\s*\)/;

export function fixProguardConfig(text){
 let changes=0;
 const content=text.replace(legacy,(_match,quote)=>{
  changes++;
  return "getDefaultProguardFile("+quote+"proguard-android-optimize.txt"+quote+")";
 });
 if(!changes&&!modern.test(text))throw Error('Could not locate the default ProGuard configuration. Inspect app/build.gradle manually.');
 return {content,changes};
}

if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const path=resolve('android/app/build.gradle');
 if(!existsSync(path))throw Error('Missing android/app/build.gradle. Run npx cap add android first.');
 const source=readFileSync(path,'utf8');
 const {content,changes}=fixProguardConfig(source);
 if(changes)writeFileSync(path,content,'utf8');
 console.log('[NovaGrid] Gradle ProGuard '+(changes?'updated to optimized default ('+changes+' occurrence(s)).':'already compatible.'));
}
