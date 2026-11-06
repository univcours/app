/* Native AdMob anchored banner stays in a separate bottom dock, never above play. */
const demo={bannerId:'ca-app-pub-3940256099942544/9214589741',interstitialId:'ca-app-pub-3940256099942544/1033173712',live:false};
const cfg=typeof __NOVA_ADS_CONFIG__!=='undefined'?__NOVA_ADS_CONFIG__:demo;
let ad=null,ready=false,loaded=false,finished=0,last=Date.now(),initializing=false;
let bannerState='not requested',interstitialState='not loaded',consentState='unknown';
export const AD_POLICY=Object.freeze({banner:true,interstitial:true,rewarded:false,rewardedInterstitial:false});
const publish=()=>{try{document.dispatchEvent(new Event('nova:ads-status'));}catch{}};
function errorMessage(e){return (e&& (e.message||e.code||e.errorCode))?String(e.message||e.code||e.errorCode):String(e);}
const log=e=>console.warn('[NovaGrid AdMob]',e);
export function getAdsStatus(){
 return {live:cfg.live,banner:bannerState,interstitial:interstitialState,consent:consentState,
  summary:(cfg.live?'LIVE':'GOOGLE TEST')+' · Banner: '+bannerState+' · Interstitial: '+interstitialState+' · Consent: '+consentState};
}
export function gameFinished(){finished++;}
/* The AdMob plugin draws a native banner ABOVE the WebView;
   this separate DOM pane reserves its footprint without using a fake ad. */
export function setBannerDock(visible,height=52){
 if(typeof document==='undefined')return;
 const root=document.documentElement,dock=document.getElementById('novaBannerDock');
 const h=Number(height);
 const pixels=visible?Math.max(60,Math.min(174,Math.ceil(Number.isFinite(h)?h:52)+12)):0;
 root.classList.toggle('native-ad-layout',!!visible);
 root.classList.toggle('no-banner',!visible);
 root.style.setProperty('--native-ad-reserve',pixels+'px');
 root.style.setProperty('--native-ad-height',visible?Math.max(0,pixels-12)+'px':'0px');
 document.body?.classList.toggle('has-native-banner',!!visible);
 if(dock){dock.hidden=!visible;dock.setAttribute('aria-hidden',String(!visible));}
 document.dispatchEvent(new Event('nova:ads-layout'));
}
export async function initializeAds(){
 setBannerDock(false);
 if(initializing||ready)return;
 if(!window.Capacitor?.isNativePlatform?.()||window.Capacitor.getPlatform()!=='android'){
  interstitialState='Android only';publish();return;
 }
 initializing=true;publish();
 try{
  const {AdMob,AdmobConsentStatus,InterstitialAdPluginEvents,BannerAdPluginEvents,BannerAdPosition,BannerAdSize}=await import('@capacitor-community/admob');
  ad=AdMob;
  // Remove any stale native banner before recreating the bottom dock.
  try{await AdMob.removeBanner();}catch{}
  let consent=await AdMob.requestConsentInfo();
  if(consent.isConsentFormAvailable&&consent.status===AdmobConsentStatus.REQUIRED)consent=await AdMob.showConsentForm();
  consentState=consent.canRequestAds?'allowed':'waiting for consent';
  const privacy=document.getElementById('privacyBtn');
  if(privacy&&consent.privacyOptionsRequirementStatus==='REQUIRED'){
   privacy.hidden=false;privacy.addEventListener('click',()=>AdMob.showPrivacyOptionsForm().catch(log));
  }
  if(!consent.canRequestAds){bannerState='blocked by consent';interstitialState='blocked by consent';publish();return;}
  await AdMob.initialize();
  ready=true;publish();
  if(!cfg.bannerId){bannerState=cfg.live?'live banner ID missing':'disabled';publish();}
  else {
   await AdMob.addListener(BannerAdPluginEvents.Loaded,()=>{bannerState='loaded';publish();});
   await AdMob.addListener(BannerAdPluginEvents.SizeChanged,size=>{
    if(Number(size?.height)>0)setBannerDock(true,Number(size.height));
    bannerState='loaded';publish();
   });
   await AdMob.addListener(BannerAdPluginEvents.FailedToLoad,error=>{
    bannerState='load failed ('+errorMessage(error)+')';
    setBannerDock(false);publish();log(error);
   });
   bannerState='loading';setBannerDock(true);publish();
   try{
    await AdMob.showBanner({
     adId:cfg.bannerId,adSize:BannerAdSize.ADAPTIVE_BANNER,
     position:BannerAdPosition.BOTTOM_CENTER,margin:0,isTesting:!cfg.live
    });
   }catch(error){
    bannerState='show failed ('+errorMessage(error)+')';
    setBannerDock(false);publish();log(error);
   }
  }
  await AdMob.addListener(InterstitialAdPluginEvents.Loaded,()=>{interstitialState='ready';publish();});
  await AdMob.addListener(InterstitialAdPluginEvents.FailedToLoad,error=>{
   interstitialState='load failed ('+errorMessage(error)+')';publish();log(error);
  });
  await AdMob.addListener(InterstitialAdPluginEvents.FailedToShow,error=>{
   interstitialState='show failed ('+errorMessage(error)+')';publish();log(error);
  });
  // Only at replay breaks: no forced interruption to gameplay.
  void prepare();
 }catch(e){bannerState='initialization failed';interstitialState='initialization failed ('+errorMessage(e)+')';setBannerDock(false);publish();log(e);}
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
