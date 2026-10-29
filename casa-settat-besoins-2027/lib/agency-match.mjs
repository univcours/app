import { COUNT_AGENCIES } from './count-agencies.mjs';
const norm = s => String(s??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toUpperCase().replace(/[^A-Z0-9]+/g,' ').trim().replace(/\s+/g,' ');
const clean = s => norm(s).replace(/^(?:(?:AGENCE|BUREAU|ABB|AP|DESTINATION|AG|ETABLISSEMENT|STE)\s+)+/,'').replace(/\s+(?:AGENCE|ABB)$/,'').trim();
export function agencySimilarity(name, candidate) {
 const a=clean(name),b=clean(candidate);
 if(!a||!b)return 0;
 if(a===b)return 1;
 const x=a.replace(/\s/g,''),y=b.replace(/\s/g,'');
 if(x===y)return .99;
 const dp=Array.from({length:y.length+1},(_,i)=>i);
 for(let i=1;i<=x.length;i++){
  let prev=dp[0];dp[0]=i;
  for(let j=1;j<=y.length;j++){
   const old=dp[j];dp[j]=Math.min(dp[j]+1,dp[j-1]+1,prev+(x[i-1]===y[j-1]?0:1));prev=old;
  }
 }
 const distance=dp[y.length],score=1-distance/Math.max(x.length,y.length);
 return Math.max(0,score);
}
export function agencyMatches(input) {
 const normalized=clean(input);
 const exact=COUNT_AGENCIES.filter(a=>clean(a)===normalized);
 if(exact.length===1)return {exact:exact[0],suggestions:[exact[0]]};
 const ranked=COUNT_AGENCIES.map(agency=>({agency,score:agencySimilarity(input,agency)})).sort((a,b)=>b.score-a.score);
 const best=ranked[0]?.score||0;
 // Suggestions are never automatically assigned. The coordinator must explicitly confirm.
 return {exact:null,suggestions:best>=0.58?ranked.filter(p=>p.score>=Math.max(0.58,best-0.20)).slice(0,5).map(p=>p.agency):[]};
}
