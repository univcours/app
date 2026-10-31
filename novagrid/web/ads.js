/* AdMob native bridge: Google test ads until Play + AdMob approval is verified.
   Exposes diagnostic states without bypassing consent or changing ad IDs. */
const demo={bannerId:'ca-app-pub-3940256099942544/6300978111',interstitialId:'ca-app-pub-3940256099942544/1033173712',live:false};
const cfg=typeof __NOVA_ADS_CONFIG__!=='undefined'?__NOVA_ADS_CONFIG__:demo;
let ad=null,ready=false,loaded=false,finished=0,last=Date.now(),initializing=false;
let bannerState='not started',interstitialState='not loaded',consentState='unknown';
const publish=()=>{try{document.dispatchEvent(new Event('nova:ads-status'));}catch{}};
function errorMessage(e){return (e&& (e.message||e.code||e.errorCode))?String(e.message||e.code||e.errorCode):String(e);}
const log=e=>console.warn('[NovaGrid AdMob]',e);
export function getAdsStatus(){
 return {live:cfg.live,banner:bannerState,interstitial:interstitialState,consent:consentState,
  summary:(cfg.live?'LIVE':'GOOGLE TEST')+' · Banner: '+bannerState+' · Interstitial: '+interstitialState+' · Consent: '+consentState};
}
export function gameFinished(){finished++;}
export async function initializeAds(){
 if(initializing||ready)return;
 if(!window.Capacitor?.isNativePlatform?.()||window.Capacitor.getPlatform()!=='android'){
  bannerState='native Android only';publish();return;
 }
 initializing=true;bannerState='starting';publish();
 try{
  const {AdMob,AdmobConsentStatus,BannerAdPluginEvents,BannerAdSize,BannerAdPosition,InterstitialAdPluginEvents}=await import('@capacitor-community/admob');
  ad=AdMob;
  let consent=await AdMob.requestConsentInfo();
  if(consent.isConsentFormAvailable&&consent.status===AdmobConsentStatus.REQUIRED)consent=await AdMob.showConsentForm();
  consentState=consent.canRequestAds?'allowed':'waiting for consent';
  const privacy=document.getElementById('privacyBtn');
  if(privacy&&consent.privacyOptionsRequirementStatus==='REQUIRED'){
   privacy.hidden=false;privacy.addEventListener('click',()=>AdMob.showPrivacyOptionsForm().catch(log));
  }
  if(!consent.canRequestAds){bannerState='blocked by consent';publish();return;}
  await AdMob.initialize();
  ready=true;publish();
  await AdMob.addListener(BannerAdPluginEvents.SizeChanged,info=>{
   const h=Math.max(0,Number(info.height)||0);
   document.documentElement.style.setProperty('--native-ad-height',h+'px');
   document.body.classList.toggle('has-native-banner',h>0);
   window.dispatchEvent(new Event('resize'));
  });
  await AdMob.addListener(BannerAdPluginEvents.Loaded,()=>{
   bannerState='loaded';publish();
  });
  await AdMob.addListener(BannerAdPluginEvents.FailedToLoad,error=>{
   bannerState='load failed ('+errorMessage(error)+')';publish();log(error);
  });
  await AdMob.addListener(InterstitialAdPluginEvents.Loaded,()=>{
   interstitialState='ready';publish();
  });
  await AdMob.addListener(InterstitialAdPluginEvents.FailedToLoad,error=>{
   interstitialState='load failed ('+errorMessage(error)+')';publish();log(error);
  });
  await AdMob.addListener(InterstitialAdPluginEvents.FailedToShow,error=>{
   interstitialState='show failed ('+errorMessage(error)+')';publish();log(error);
  });
  bannerState='requesting';publish();
  await AdMob.showBanner({adId:cfg.bannerId,adSize:BannerAdSize.ADAPTIVE_BANNER,
   position:BannerAdPosition.BOTTOM_CENTER,margin:0,isTesting:!cfg.live});
  void prepare();
 }catch(e){bannerState='initialization failed ('+errorMessage(e)+')';publish();log(e);}
 finally{initializing=false;}
}
async function prepare(){
 if(!ready||loaded||!ad)return;
 interstitialState='loading';publish();
 try{await ad.prepareInterstitial({adId:cfg.interstitialId,isTesting:!cfg.live});loaded=true;interstitialState='ready';publish();}
 catch(e){interstitialState='load failed ('+errorMessage(e)+')';publish();log(e);}
}
async function showPrepared(){
 if(!ready||!loaded)return false;
 loaded=false;interstitialState='showing';publish();
 try{await ad.showInterstitial({adId:cfg.interstitialId});interstitialState='shown';return true;}
 catch(e){interstitialState='show failed ('+errorMessage(e)+')';log(e);return false;}
 finally{publish();void prepare();}
}
export async function maybeShowInterstitialOnReplay(){
 // Natural break only; never interrupt active playing or flood repeated ads.
 if(!ready||!loaded||finished<2||Date.now()-last<180000)return false;
 last=Date.now();return showPrepared();
}
export async function tryTestInterstitial(){
 if(cfg.live)return 'Manual AdMob test disabled on live builds.';
 if(!window.Capacitor?.isNativePlatform?.())return 'Open the installed Android app to test.';
 if(!ready)return 'AdMob not initialized: '+getAdsStatus().summary;
 if(!loaded){void prepare();return 'Test interstitial not ready yet: '+interstitialState;}
 return (await showPrepared())?'Test interstitial requested successfully.':getAdsStatus().summary;
}
