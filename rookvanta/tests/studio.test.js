import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {io as ioClient} from 'socket.io-client';
import {createGameServer} from '../server.js';
import {normalizeCountry,countryFlag,COUNTRY_CODES} from '../public/countries.js';

const html=readFileSync(new URL('../public/index.html',import.meta.url),'utf8');
const css=readFileSync(new URL('../public/styles.css',import.meta.url),'utf8');
const clientCode=readFileSync(new URL('../public/client.js',import.meta.url),'utf8');

function connect(url){
 return new Promise((resolve,reject)=>{
  const s=ioClient(url,{transports:['websocket'],reconnection:false});
  s.once('connect',()=>resolve(s));
  s.once('connect_error',reject);
 });
}
function send(s,event,payload={}){return new Promise((resolve,reject)=>s.timeout(4000).emit(event,payload,(err,response)=>err?reject(err):resolve(response)));}
function eventOnce(s,name){return new Promise((resolve,reject)=>{
 const id=setTimeout(()=>reject(Error('Timeout for '+name)),4000);
 s.once(name,msg=>{clearTimeout(id);resolve(msg);});
});}

test('tournament studio has separate country flags and dynamic turn banner',()=>{
 for(const id of ['playerCountry','studioWhiteFlag','studioBlackFlag','studioWhiteName','studioBlackName',
 'studioLiveLabel','studioFormat','studioMatchType','studioPly','turnRibbon','turnHeadline',
 'turnDetail','turnSymbol','meFlag','opponentFlag','meCountry','opponentCountry']){
  assert.match(html,new RegExp('id="'+id+'"'),id);
 }
 assert.match(css,/\.turn-ribbon\.my-turn/);
 assert.match(css,/\.turn-ribbon\.check-alert/);
 assert.match(css,/\.studio-broadcast/);
 assert.match(css,/@media\(max-width:650px\)/);
 assert.match(clientCode,/function updateStudio\(\)/);
 assert.match(clientCode,/countryFlag\(player\?\.country\)/);
 assert.match(clientCode,/state\.lastMove\?\.from/);
});
test('flag picker uses full ISO country catalogue with opt-out',()=>{
 assert.ok(COUNTRY_CODES.length>=240);
 assert.equal(normalizeCountry('MA'),'MA');
 assert.equal(countryFlag('MA'),'🇲🇦');
 assert.equal(normalizeCountry('<img>'),'');
 assert.match(html,/<option value="">🌐 International<\/option>/);
});
test('private competition shows voluntary nationality and latest move to both clients',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});
 t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const w=await connect(url),b=await connect(url);
 t.after(()=>{w.disconnect();b.disconnect();});
 const wMessage=eventOnce(w,'room:state');
 const created=await send(w,'room:create',{name:'Casablanca',country:'ma',time:'5+0'});
 assert.equal(created.ok,true);
 const initial=await wMessage;
 assert.equal(initial.players.find(p=>p.color==='w').country,'MA');
 const blackMessage=eventOnce(b,'room:state');
 const joined=await send(b,'room:join',{code:created.code,name:'Paris',country:'fr'});
 assert.equal(joined.ok,true);
 const start=await blackMessage;
 assert.equal(start.started,true);
 assert.equal(start.players.find(p=>p.color==='b').country,'FR');
 assert.equal(start.turn,'w');assert.equal(start.lastMove,null);
 const moveSent=eventOnce(b,'room:state');
 assert.equal((await send(w,'room:move',{from:'e2',to:'e4'})).ok,true);
 const next=await moveSent;
 assert.equal(next.turn,'b');
 assert.deepEqual(next.lastMove,{from:'e2',to:'e4',san:'e4'});
 assert.equal(next.players.find(p=>p.color==='w').country,'MA');
 assert.equal(next.players.find(p=>p.color==='b').country,'FR');
});
test('global matchmaking keeps each player-selected flag even with random assigned side',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});
 t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const s1=await connect(url),s2=await connect(url);
 t.after(()=>{s1.disconnect();s2.disconnect();});
 assert.equal((await send(s1,'matchmaking:search',{name:'Rabat',country:'MA',time:'3+2'})).status,'waiting');
 const match=await send(s2,'matchmaking:search',{name:'São Paulo',country:'BR',time:'3+2'});
 assert.equal(match.status,'matched');
 const room=server.rooms.get(match.code);
 assert.ok(room);
 assert.equal(room.players.find(p=>p.name==='Rabat').country,'MA');
 assert.equal(room.players.find(p=>p.name==='São Paulo').country,'BR');
 assert.notEqual(room.players[0].color,room.players[1].color);
});
test('unrecognized or forged country values cannot appear as arbitrary flags',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const a=await connect(url);t.after(()=>a.disconnect());
 const created=await send(a,'room:create',{name:'Anon',country:'🚩 fake'});
 assert.equal(created.ok,true);
 assert.equal(server.rooms.get(created.code).players[0].country,'');
});
