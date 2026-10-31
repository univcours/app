import {cpSync,rmSync,mkdirSync} from 'node:fs';
import {build} from 'esbuild';
const real=process.env.ADMOB_LIVE_ADS==='true';
const appId=process.env.ADMOB_ANDROID_APP_ID||'';
const banner=process.env.ADMOB_BANNER_UNIT_ID||'';
const interstitial=process.env.ADMOB_INTERSTITIAL_UNIT_ID||'';
const appValid=/^ca-app-pub-[0-9]{16}~[0-9]{10}$/;
const unitValid=/^ca-app-pub-[0-9]{16}\/[0-9]{10}$/;
if(real&&(!appValid.test(appId)||!unitValid.test(banner)||!unitValid.test(interstitial)||
  [appId,banner,interstitial].some(x=>x.includes('3940256099942544'))))
 throw Error('Live ads blocked: require verified AdMob App ID, Banner ID and Interstitial ID.');
const config=real?{bannerId:banner,interstitialId:interstitial,live:true}:
 {bannerId:'ca-app-pub-3940256099942544/6300978111',interstitialId:'ca-app-pub-3940256099942544/1033173712',live:false};
rmSync('dist',{recursive:true,force:true});mkdirSync('dist',{recursive:true});cpSync('web','dist',{recursive:true});
await build({entryPoints:['web/app.js'],outfile:'dist/app.js',bundle:true,format:'esm',platform:'browser',target:'es2020',
 define:{__NOVA_ADS_CONFIG__:JSON.stringify(config)}});
console.log('NovaGrid ready; AdMob mode:',real?'LIVE':'GOOGLE DEMO');
