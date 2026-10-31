import sharp from 'sharp';
import {existsSync,mkdirSync} from 'node:fs';
import {join} from 'node:path';

const source='web/logo.webp';
const root='android/app/src/main/res';
if(!existsSync(source)||!existsSync(root))throw Error('Generate native Android project first and ensure web/logo.webp exists.');
const sizes={mdpi:48,hdpi:72,xhdpi:96,xxhdpi:144,xxxhdpi:192};
for(const [density,size] of Object.entries(sizes)){
 const dir=join(root,'mipmap-'+density);mkdirSync(dir,{recursive:true});
 const icon=await sharp(source).resize(size,size,{fit:'cover'}).png().toBuffer();
 await sharp(icon).toFile(join(dir,'ic_launcher.png'));
 await sharp(source).resize(size,size,{fit:'cover'}).png().toFile(join(dir,'ic_launcher_round.png'));
 const fgSize=Math.round(size*1.4);
 const artwork=await sharp(source).resize(Math.floor(fgSize*.72),Math.floor(fgSize*.72),{fit:'contain'}).png().toBuffer();
 const canvas=await sharp({create:{width:fgSize,height:fgSize,channels:4,background:{r:0,g:0,b:0,alpha:0}}})
  .composite([{input:artwork,gravity:'center'}]).png().toBuffer();
 await sharp(canvas).toFile(join(dir,'ic_launcher_foreground.png'));
}
const anydpi=join(root,'mipmap-anydpi-v26');mkdirSync(anydpi,{recursive:true});
console.log('[NovaGrid] Launcher icons generated from the approved cosmic logo.');
