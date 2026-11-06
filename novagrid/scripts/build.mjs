import {cpSync,rmSync,mkdirSync} from 'node:fs';
import {build} from 'esbuild';
const real=process.env.ADMOB_LIVE_ADS==='true';
const appId=process.env.ADMOB_ANDROID_APP_ID||'ca-app-pub-7945572016731367~1688423435';
const interstitial=process.env.ADMOB_INTERSTITIAL_UNIT_ID||'ca-app-pub-7945572016731367/2422920606';
// The live banner unit must be supplied by the owner. Never invent or borrow it.
const banner=process.env.ADMOB_BANNER_UNIT_ID||'';
const appValid=/^ca-app-pub-[0-9]{16}~[0-9]{10}$/;
const unitValid=/^ca-app-pub-[0-9]{16}\/[0-9]{10}$/;
if(real&&(!appValid.test(appId)||!unitValid.test(interstitial)||(banner&&!unitValid.test(banner))||
  [appId,interstitial,banner].some(x=>x.includes('3940256099942544'))))
 throw Error('Live ads blocked: require verified AdMob App ID and Interstitial ID.');
const config=real?{interstitialId:interstitial,bannerId:banner||null,live:true}:
 {interstitialId:'ca-app-pub-3940256099942544/1033173712',bannerId:'ca-app-pub-3940256099942544/9214589741',live:false};
rmSync('dist',{recursive:true,force:true});mkdirSync('dist',{recursive:true});cpSync('web','dist',{recursive:true});
await build({entryPoints:['web/app.js'],outfile:'dist/app.js',bundle:true,format:'esm',platform:'browser',target:'es2020',
 define:{__NOVA_ADS_CONFIG__:JSON.stringify(config)}});
console.log('NovaGrid ready; AdMob mode:',real?'LIVE':'GOOGLE DEMO');
if(real&&!banner)console.warn('LIVE banner disabled until ADMOB_BANNER_UNIT_ID is configured. No guessed ad ID is used.');
