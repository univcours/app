import test from 'node:test';
import assert from 'node:assert/strict';
import {io as connectSocket} from 'socket.io-client';
import {createGameServer} from '../server.js';

function connect(url){
 return new Promise((resolve,reject)=>{
  const s=connectSocket(url,{transports:['websocket'],reconnection:false});
  const failed=e=>{s.disconnect();reject(e);};
  s.once('connect_error',failed);
  s.once('connect',()=>{s.off('connect_error',failed);resolve(s);});
 });
}
function send(socket,event,payload={}){
 return new Promise((resolve,reject)=>{
  socket.timeout(5000).emit(event,payload,(err,res)=>err?reject(err):resolve(res));
 });
}
function once(socket,event){
 return new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>{socket.off(event,handler);reject(new Error(event+' timed out'));},4000);
  function handler(data){clearTimeout(timer);resolve(data);}
  socket.once(event,handler);
 });
}
test('two anonymous players from any location match automatically with a valid chess board',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});
 t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const first=await connect(url),second=await connect(url);
 t.after(()=>{first.disconnect();second.disconnect();});
 const found=once(first,'matchmaking:found');
 const waiting=await send(first,'matchmaking:search',{name:'Casablanca 🇲🇦',time:'5+0'});
 assert.deepEqual(waiting,{ok:true,status:'waiting',time:'5+0'});
 assert.equal(server.waiting.size,1);
 const matched=await send(second,'matchmaking:search',{name:'Tokyo 🇯🇵',time:'5+0'});
 const received=await found;
 assert.equal(matched.ok,true);
 assert.equal(matched.status,'matched');
 assert.equal(received.code,matched.code);
 assert.notEqual(received.token,matched.token);
 assert.notEqual(received.color,matched.color);
 assert.equal(server.rooms.get(matched.code).matchType,'global');
 assert.equal(server.rooms.get(matched.code).started,true);
 assert.equal(server.waiting.size,0);
 assert.equal(server.queues.get('5+0').size,0);
 const white=received.color==='w'?first:second;
 const black=white===first?second:first;
 assert.equal((await send(white,'room:move',{from:'e2',to:'e4'})).ok,true);
 assert.equal((await send(black,'room:move',{from:'e7',to:'e5'})).ok,true);
 assert.equal(server.rooms.get(matched.code).chess.history().length,2);
});
test('time control queues stay independent and cancellation never pairs a cancelled player',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const a=await connect(url),b=await connect(url),c=await connect(url);
 t.after(()=>{a.disconnect();b.disconnect();c.disconnect();});
 assert.equal((await send(a,'matchmaking:search',{name:'A',time:'3+2'})).status,'waiting');
 assert.equal((await send(b,'matchmaking:search',{name:'B',time:'10+0'})).status,'waiting');
 assert.equal(server.waiting.size,2);
 const duplicate=await send(a,'matchmaking:search',{name:'A2',time:'3+2'});
 assert.equal(duplicate.status,'waiting');
 assert.equal(server.queues.get('3+2').size,1);
 assert.equal((await send(a,'matchmaking:search',{time:'10+0'})).ok,false);
 assert.equal((await send(a,'matchmaking:cancel',{})).cancelled,true);
 assert.equal((await send(a,'matchmaking:cancel',{})).cancelled,false);
 assert.equal(server.waiting.size,1);
 const found=once(b,'matchmaking:found');
 const matched=await send(c,'matchmaking:search',{name:'C',time:'10+0'});
 assert.equal(matched.status,'matched');assert.equal((await found).code,matched.code);
 assert.equal(server.waiting.size,0);
});
test('disconnected waiting players are removed and cannot receive a ghost match',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const a=await connect(url);t.after(()=>a.disconnect());
 assert.equal((await send(a,'matchmaking:search',{time:'5+0'})).status,'waiting');
 a.disconnect();
 await new Promise(r=>setTimeout(r,75));
 assert.equal(server.waiting.size,0);
 const b=await connect(url);t.after(()=>b.disconnect());
 assert.equal((await send(b,'matchmaking:search',{time:'5+0'})).status,'waiting');
 assert.equal(server.rooms.size,0);
});
test('a public match blocks additional searches and private-room intrusion',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const a=await connect(url),b=await connect(url),c=await connect(url);
 t.after(()=>{a.disconnect();b.disconnect();c.disconnect();});
 await send(a,'matchmaking:search',{time:'5+0'});
 const paired=await send(b,'matchmaking:search',{time:'5+0'});
 assert.equal(paired.status,'matched');
 assert.equal((await send(a,'matchmaking:search',{time:'5+0'})).ok,false);
 assert.equal((await send(b,'matchmaking:search',{time:'5+0'})).ok,false);
 assert.equal((await send(c,'room:join',{code:paired.code,name:'Intruder'})).ok,false);
 const s=await send(b,'room:resign',{});
 assert.equal(s.ok,true);
 assert.equal((await send(b,'matchmaking:search',{time:'5+0'})).status,'waiting');
});
test('user switching from queued search to private room is removed from global queue',async t=>{
 const server=await createGameServer({port:0,host:'127.0.0.1'});t.after(()=>server.close());
 const url='http://127.0.0.1:'+server.port;
 const a=await connect(url);t.after(()=>a.disconnect());
 await send(a,'matchmaking:search',{time:'3+2'});
 assert.equal(server.waiting.size,1);
 const created=await send(a,'room:create',{name:'Me',time:'3+2'});
 assert.equal(created.ok,true);assert.equal(server.waiting.size,0);
 const b=await connect(url);t.after(()=>b.disconnect());
 assert.equal((await send(b,'matchmaking:search',{time:'3+2'})).status,'waiting');
});
