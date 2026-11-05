/* AdMob native bridge: Google test ads until Play + AdMob approval is verified.
   Exposes diagnostic states without bypassing consent or changing ad IDs. */
const demo={bannerId:'ca-app-pub-3940256099942544/6300978111',interstitialId:'ca-app-pub-3940256099942544/1033173712',rewardedId:'ca-app-pub-3940256099942544/5224354917',live:false};
const cfg=typeof __NOVA_ADS_CONFIG__!=='undefined'?__NOVA_ADS_CONFIG__:demo;
let ad=null,ready=false,loaded=false,finished=0,last=Date.now(),initializing=false;
let rewardedLoaded=false,rewardPreparing=null,rewardBusy=false,rewardedState='not loaded';
let bannerState='disabled (full-screen game)',interstitialState='not loaded',consentState='unknown';
export const AD_POLICY=Object.freeze({banner:false,interstitial:true,rewarded:true,rewardedInterstitial:false});
const publish=()=>{try{document.dispatchEvent(new Event('nova:ads-status'));}catch{}};
function errorMessage(e){return (e&& (e.message||e.code||e.errorCode))?String(e.message||e.code||e.errorCode):String(e);}
const log=e=>console.warn('[NovaGrid AdMob]',e);
export function getAdsStatus(){
 return {live:cfg.live,banner:bannerState,interstitial:interstitialState,rewarded:rewardedState,consent:consentState,
  summary:(cfg.live?'LIVE':'GOOGLE TEST')+' · Banner: '+bannerState+' · Interstitial: '+interstitialState+' · Rewarded: '+rewardedState+' · Consent: '+consentState};
}
export function gameFinished(){finished++;}
function applyBannerFreeLayout(){
 if(typeof document==='undefined')return;
 document.documentElement.classList.remove('native-ad-layout');
 document.documentElement.classList.add('no-banner');
 document.documentElement.style.setProperty('--native-ad-reserve','0px');
 document.documentElement.style.setProperty('--native-ad-height','0px');
 document.body?.classList.remove('has-native-banner');
 document.dispatchEvent(new Event('nova:ads-layout'));
}
export async function initializeAds(){
 applyBannerFreeLayout();
 if(initializing||ready)return;
 if(!window.Capacitor?.isNativePlatform?.()||window.Capacitor.getPlatform()!=='android'){
  interstitialState='Android only';publish();return;
 }
 initializing=true;publish();
 try{
  const {AdMob,AdmobConsentStatus,InterstitialAdPluginEvents}=await import('@capacitor-community/admob');
  ad=AdMob;
  // Removes stale native banner from prior sessions. Never request banners again.
  try{await AdMob.removeBanner();}catch{}
  let consent=await AdMob.requestConsentInfo();
  if(consent.isConsentFormAvailable&&consent.status===AdmobConsentStatus.REQUIRED)consent=await AdMob.showConsentForm();
  consentState=consent.canRequestAds?'allowed':'waiting for consent';
  const privacy=document.getElementById('privacyBtn');
  if(privacy&&consent.privacyOptionsRequirementStatus==='REQUIRED'){
   privacy.hidden=false;privacy.addEventListener('click',()=>AdMob.showPrivacyOptionsForm().catch(log));
  }
  if(!consent.canRequestAds){interstitialState='blocked by consent';publish();return;}
  await AdMob.initialize();
  ready=true;publish();
  await AdMob.addListener(InterstitialAdPluginEvents.Loaded,()=>{interstitialState='ready';publish();});
  await AdMob.addListener(InterstitialAdPluginEvents.FailedToLoad,error=>{
   interstitialState='load failed ('+errorMessage(error)+')';publish();log(error);
  });
  await AdMob.addListener(InterstitialAdPluginEvents.FailedToShow,error=>{
   interstitialState='show failed ('+errorMessage(error)+')';publish();log(error);
  });
  // Only at replay breaks: no forced interruption to gameplay.
  void prepare();
  void prepareReward();
 }catch(e){interstitialState='initialization failed ('+errorMessage(e)+')';publish();log(e);}
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
async function prepareReward(){
 if(!ready||!ad||!cfg.rewardedId)return false;
 if(rewardedLoaded)return true;
 if(rewardPreparing)return rewardPreparing;
 rewardedState='loading';publish();
 rewardPreparing=ad.prepareRewardVideoAd({adId:cfg.rewardedId,isTesting:!cfg.live})
  .then(()=>{rewardedLoaded=true;rewardedState='ready';publish();return true;})
  .catch(e=>{rewardedState='load failed ('+errorMessage(e)+')';publish();log(e);return false;})
  .finally(()=>{rewardPreparing=null;});
 return rewardPreparing;
}
export async function showOptionalReward(){
 // Reward only on the SDK's earned result. No grant on ad dismissal or load failure.
 if(!ready||rewardBusy||!cfg.rewardedId)return false;
 rewardBusy=true;
 try{
  if(!(await prepareReward()))return false;
  rewardedLoaded=false;rewardedState='showing';publish();
  const reward=await ad.showRewardVideoAd({adId:cfg.rewardedId});
  const earned=!!reward&&Number(reward.amount)>0;
  rewardedState=earned?'earned':'not earned';publish();
  return earned;
 }catch(e){rewardedState='not earned ('+errorMessage(e)+')';publish();log(e);return false;}
 finally{rewardBusy=false;void prepareReward();}
}
export async function maybeShowInterstitialOnReplay(){
 // Natural break only; never interrupt active playing or flood repeated ads.
 if(!ready||!loaded||finished<3||Date.now()-last<240000)return false;
 last=Date.now();return showPrepared();
}
export async function tryTestInterstitial(){
 if(cfg.live)return 'Manual AdMob test disabled on live builds.';
 if(!window.Capacitor?.isNativePlatform?.())return 'Open the installed Android app to test.';
 if(!ready)return 'AdMob not initialized: '+getAdsStatus().summary;
 if(!loaded){void prepare();return 'Test interstitial not ready yet: '+interstitialState;}
 return (await showPrepared())?'Test interstitial requested successfully.':getAdsStatus().summary;
}
