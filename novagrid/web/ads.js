// AdMob is loaded only in packaged Android builds. Test ads are always the default.
const demo={bannerId:'ca-app-pub-3940256099942544/6300978111',interstitialId:'ca-app-pub-3940256099942544/1033173712',live:false};
const cfg=typeof __NOVA_ADS_CONFIG__!=='undefined'?__NOVA_ADS_CONFIG__:demo;
let ad=null,ready=false,loaded=false,finished=0,last=Date.now();
const warn=e=>console.warn('[NovaGrid AdMob]',e);
export function gameFinished(){finished++;}
export async function initializeAds(){
 if(!window.Capacitor?.isNativePlatform?.()||window.Capacitor.getPlatform()!=='android')return;
 try{
  const {AdMob,AdmobConsentStatus,BannerAdPluginEvents,BannerAdSize,BannerAdPosition}=await import('@capacitor-community/admob');
  ad=AdMob;
  let consent=await AdMob.requestConsentInfo();
  if(consent.isConsentFormAvailable&&consent.status===AdmobConsentStatus.REQUIRED)consent=await AdMob.showConsentForm();
  const privacy=document.getElementById('privacyBtn');
  if(privacy&&consent.privacyOptionsRequirementStatus==='REQUIRED'){
   privacy.hidden=false;privacy.addEventListener('click',()=>AdMob.showPrivacyOptionsForm().catch(warn));
  }
  if(!consent.canRequestAds)return; // Fail closed when UMP is unavailable.
  await AdMob.initialize();ready=true;
  await AdMob.addListener(BannerAdPluginEvents.SizeChanged,info=>{
   const h=Math.max(0,Number(info.height)||0);
   document.documentElement.style.setProperty('--native-ad-height',h+'px');
   document.body.classList.toggle('has-native-banner',h>0);
   window.dispatchEvent(new Event('resize'));
  });
  await AdMob.showBanner({adId:cfg.bannerId,adSize:BannerAdSize.ADAPTIVE_BANNER,
   position:BannerAdPosition.BOTTOM_CENTER,margin:0,isTesting:!cfg.live});
  void prepare();
 }catch(e){warn(e);}
}
async function prepare(){if(!ready||loaded)return;try{await ad.prepareInterstitial({adId:cfg.interstitialId,isTesting:!cfg.live});loaded=true;}catch(e){warn(e);}}
export async function maybeShowInterstitialOnReplay(){
 if(!ready||!loaded||finished<2||Date.now()-last<180000)return;
 last=Date.now();loaded=false;
 try{await ad.showInterstitial({adId:cfg.interstitialId});}catch(e){warn(e);}
 void prepare();
}