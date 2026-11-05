import {cpSync,rmSync,mkdirSync} from 'node:fs';
import {build} from 'esbuild';
const real=process.env.ADMOB_LIVE_ADS==='true';
const appId=process.env.ADMOB_ANDROID_APP_ID||'ca-app-pub-7945572016731367~1688423435';
const interstitial=process.env.ADMOB_INTERSTITIAL_UNIT_ID||'ca-app-pub-7945572016731367/2422920606';
const rewarded=process.env.ADMOB_REWARDED_UNIT_ID||'ca-app-pub-7945572016731367/1367989694';
const appValid=/^ca-app-pub-[0-9]{16}~[0-9]{10}$/;
const unitValid=/^ca-app-pub-[0-9]{16}\/[0-9]{10}$/;
if(real&&(!appValid.test(appId)||!unitValid.test(interstitial)||!unitValid.test(rewarded)||
  [appId,interstitial,rewarded].some(x=>x.includes('3940256099942544'))))
 throw Error('Live ads blocked: require verified AdMob App ID and Interstitial ID.');
const config=real?{interstitialId:interstitial,rewardedId:rewarded,live:true}:
 {interstitialId:'ca-app-pub-3940256099942544/1033173712',rewardedId:'ca-app-pub-3940256099942544/5224354917',live:false};
rmSync('dist',{recursive:true,force:true});mkdirSync('dist',{recursive:true});cpSync('web','dist',{recursive:true});
// Ship only the continuous game; the original stage source stays recoverable in Git history.
for(const unused of ['galaxy-ui.js','galaxy.css','stages.js'])rmSync('dist/'+unused,{force:true});
await build({entryPoints:['web/app.js'],outfile:'dist/app.js',bundle:true,format:'esm',platform:'browser',target:'es2020',
 define:{__NOVA_ADS_CONFIG__:JSON.stringify(config)}});
console.log('NovaGrid ready; AdMob mode:',real?'LIVE':'GOOGLE DEMO');
