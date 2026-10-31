/* Keep Android launcher + task switcher title equal to the public app name.
   Capacitor generates android/ locally and cap sync may leave old strings behind. */
import {existsSync,readFileSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';

export const DISPLAY_NAME='NovaGrid';
export function renameAndroidStrings(xml){
 let found=0;
 const result=xml.replace(/(<string\s+name=["'](?:app_name|title_activity_main)["'][^>]*>)([\s\S]*?)(<\/string>)/g,(_full,start,_old,end)=>{
  found++;return start+DISPLAY_NAME+end;
 });
 if(found<2)throw Error('Expected app_name and title_activity_main in Android strings.xml');
 return result;
}
const filepath=join('android','app','src','main','res','values','strings.xml');
if(process.argv[1]&&import.meta.url===new URL('file://'+process.argv[1].replace(/\\/g,'/')).href){
 if(!existsSync(filepath))throw Error('Generate Android first with npx cap add android');
 const before=readFileSync(filepath,'utf8'),after=renameAndroidStrings(before);
 if(before!==after)writeFileSync(filepath,after);
 console.log('[NovaGrid] Android launcher and activity display name:',DISPLAY_NAME);
}
