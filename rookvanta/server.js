import http from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {randomBytes} from 'node:crypto';
import {Server} from 'socket.io';
import {Chess} from 'chess.js';
import {normalizeCountry} from './public/countries.js';

const publicDir=fileURLToPath(new URL('./public/',import.meta.url));
const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const timeOptions=new Map([['3+2',[180000,2000]],['5+0',[300000,0]],['10+0',[600000,0]]]);
const mime={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.webmanifest':'application/manifest+json','.json':'application/json','.ico':'image/x-icon'};
const code=()=>Array.from(randomBytes(6),n=>alphabet[n%alphabet.length]).join('');
const token=()=>randomBytes(24).toString('hex');
const name=s=>String(s||'Player').trim().replace(/[<>]/g,'').slice(0,24)||'Player';
const safeAck=(cb,response)=>{if(typeof cb==='function')cb(response);};
export function createGameServer({port=Number(process.env.PORT)||3000,host='0.0.0.0'}={}){
 const rooms=new Map();
 const queues=new Map([...timeOptions.keys()].map(label=>[label,new Set()]));
 const waiting=new Map();
 const handler=async(req,res)=>{
  const pathname=new URL(req.url,'http://localhost').pathname;
  if(pathname==='/health'){res.writeHead(200,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify({ok:true,service:'RookVanta'}));return;}
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405);res.end();return;}
  const candidate=resolve(publicDir,'.'+(pathname==='/'?'/index.html':pathname));
  if(!candidate.startsWith(publicDir+sep)&&candidate!==resolve(publicDir,'index.html')){res.writeHead(403);res.end();return;}
  try{
   const info=await stat(candidate);
   if(!info.isFile())throw new Error('not a file');
   const contents=await readFile(candidate);
   res.writeHead(200,{'content-type':mime[extname(candidate)]||'application/octet-stream','cache-control':'no-cache','x-content-type-options':'nosniff'});
   if(req.method==='HEAD')res.end();else res.end(contents);
  }catch{res.writeHead(404,{'content-type':'text/plain'});res.end('Not found');}
 };
 const httpServer=http.createServer(handler);
 const io=new Server(httpServer,{maxHttpBufferSize:4096,transports:['websocket','polling']});
 const getSeat=(room,socket)=>room?.players?.find(p=>p&&p.socket===socket.id);
 function clocks(room,at=Date.now()){
  const times={...room.timeLeft};
  if(room.started&&!room.result&&room.activeSince!==null){
   times[room.chess.turn()]=Math.max(0,times[room.chess.turn()]-(at-room.activeSince));
  }
  return times;
 }
 function refreshClock(room){
  if(!room.started||room.result)return;
  const now=Date.now(),current=room.chess.turn();
  const rem=clocks(room,now);
  room.timeLeft=rem;room.activeSince=now;
  if(rem[current]<=0){
   room.timeLeft[current]=0;room.result={winner:current==='w'?'b':'w',reason:'timeout'};
   if(room.chess.isInsufficientMaterial())room.result={winner:null,reason:'timeout-insufficient-material'};
   room.activeSince=null;
  }
 }
 function state(room,socket){
  const color=getSeat(room,socket)?.color??null;
  const moves=room.started&&!room.result&&color===room.chess.turn()
   ?room.chess.moves({verbose:true}).map(m=>({from:m.from,to:m.to,promotion:m.promotion||null})):[],now=Date.now();
  const past=room.chess.history({verbose:true}),last=past.at(-1);
  return {code:room.id,color,fen:room.chess.fen(),turn:room.chess.turn(),history:past.map(m=>m.san),
   lastMove:last?{from:last.from,to:last.to,san:last.san}:null,
   legalMoves:moves,check:room.chess.isCheck(),started:room.started,result:room.result,clocks:clocks(room,now),
   serverTime:now,increment:room.increment,base:room.base,timeLabel:room.timeLabel,
   players:room.players.map(p=>p?{color:p.color,name:p.name,country:p.country||'',online:!!p.socket,readyRematch:!!p.rematch}:null),
   drawOffer:room.drawOffer,matchType:room.matchType||'private'};
 }
 function broadcast(room,{touch=true}={}){
  if(touch)room.updated=Date.now();
  for(const p of room.players){if(p?.socket){const s=io.sockets.sockets.get(p.socket);if(s)s.emit('room:state',state(room,s));}}
 }
 function queueNumbers(){
  return {total:waiting.size,byTime:Object.fromEntries([...queues].map(([label,q])=>[label,q.size]))};
 }
 function queueBroadcast(){io.emit('matchmaking:population',queueNumbers());}
 function queueRemove(id){
  const existing=waiting.get(id);if(!existing)return false;
  waiting.delete(id);queues.get(existing.time)?.delete(id);return true;
 }
 function queueStatus(socket){
  socket.emit('matchmaking:population',queueNumbers());
 }
 function joinSocket(socket,room,player){
  if(queueRemove(socket.id))queueBroadcast();
  if(socket.data.roomId&&socket.data.roomId!==room.id){const old=rooms.get(socket.data.roomId);if(old){const prev=getSeat(old,socket);if(prev)prev.socket=null;broadcast(old);}socket.leave(socket.data.roomId);}
  if(player.socket&&player.socket!==socket.id){
   const old=io.sockets.sockets.get(player.socket);
   if(old){old.data.roomId=null;old.emit('room:replaced');old.leave(room.id);}
  }
  player.socket=socket.id;
  socket.data.roomId=room.id;
  socket.join(room.id);room.updated=Date.now();
 }
 function roomEvent(socket,event,handler){
  socket.on(event,(payload,ack)=>{
   try{
    if(typeof payload!=='object'||payload===null||Array.isArray(payload))throw Error('Invalid request');
    const room=rooms.get(socket.data.roomId),seat=getSeat(room,socket);
    if(!room||!seat)throw Error('Join a match first');
    handler(room,seat,payload,ack);
   }catch(e){safeAck(ack,{ok:false,error:String(e.message||e)});}
  });
 }
 io.on('connection',socket=>{
  queueStatus(socket);
  socket.on('room:create',(payload={},ack)=>{
   try{
    const timeLabel=timeOptions.has(payload.time)?payload.time:'5+0';
    const [base,increment]=timeOptions.get(timeLabel);
    let id=code();while(rooms.has(id))id=code();
    const first={name:name(payload.name),country:normalizeCountry(payload.country),color:'w',token:token(),socket:null,rematch:false};
    const room={id,chess:new Chess(),players:[first,null],base,increment,timeLabel,
     timeLeft:{w:base,b:base},activeSince:null,started:false,result:null,drawOffer:null,updated:Date.now()};
    rooms.set(id,room);joinSocket(socket,room,first);safeAck(ack,{ok:true,code:id,token:first.token,color:'w'});
    broadcast(room);
   }catch(e){safeAck(ack,{ok:false,error:String(e.message||e)});}
  });
  socket.on('room:join',(payload={},ack)=>{
   try{
    const id=String(payload.code||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
    const room=rooms.get(id);
    if(!room)throw Error('Room not found or expired');
    let p=room.players.find(x=>x&&x.token===payload.token&&typeof payload.token==='string');
    if(!p){if(getSeat(room,socket))throw Error('Already seated in this room');if(room.players[1])throw Error('Room full — two players already joined');
     p={name:name(payload.name),country:normalizeCountry(payload.country),color:'b',token:token(),socket:null,rematch:false};room.players[1]=p;
    }
    joinSocket(socket,room,p);
    if(room.players[0]&&room.players[1]&&!room.started){room.started=true;room.activeSince=Date.now();}
    safeAck(ack,{ok:true,code:id,token:p.token,color:p.color});
    broadcast(room);
   }catch(e){safeAck(ack,{ok:false,error:String(e.message||e)});}
  });
  // Globally shared FIFO matchmaking. No geographic restrictions or room codes.
  socket.on('matchmaking:search',(payload={},ack)=>{
   try{
    if(!payload||typeof payload!=='object'||Array.isArray(payload))throw Error('Invalid request');
    const time=String(payload.time||'5+0');
    if(!timeOptions.has(time))throw Error('Unsupported time control');
    const room=rooms.get(socket.data.roomId);
    if(room?.started&&!room.result&&getSeat(room,socket))
     throw Error('Finish your active match before searching again');
    if(waiting.has(socket.id)){
     const previous=waiting.get(socket.id);
     if(previous.time!==time)throw Error('Cancel the current search before changing the time');
     safeAck(ack,{ok:true,status:'waiting',time});return;
    }
    const pool=queues.get(time);
    let opponent=null;
    while(pool.size){
     const id=pool.values().next().value;
     const seat=waiting.get(id),peer=io.sockets.sockets.get(id);
     if(!seat||!peer||!peer.connected){queueRemove(id);continue;}
     if(id===socket.id)break;
     opponent={socket:peer,...seat};break;
    }
    if(!opponent){
     waiting.set(socket.id,{name:name(payload.name),country:normalizeCountry(payload.country),time,since:Date.now()});
     pool.add(socket.id);
     safeAck(ack,{ok:true,status:'waiting',time});
     queueBroadcast();return;
    }
    queueRemove(opponent.socket.id);
    const [base,increment]=timeOptions.get(time);
    let id=code();while(rooms.has(id))id=code();
    const firstWhite=(randomBytes(1)[0]&1)===0;
    const first={name:opponent.name,country:opponent.country||'',color:firstWhite?'w':'b',token:token(),socket:null,rematch:false};
    const second={name:name(payload.name),country:normalizeCountry(payload.country),color:firstWhite?'b':'w',token:token(),socket:null,rematch:false};
    const roomNew={id,chess:new Chess(),players:[first,second],base,increment,timeLabel:time,
      timeLeft:{w:base,b:base},activeSince:Date.now(),started:true,result:null,drawOffer:null,
      matchType:'global',updated:Date.now()};
    rooms.set(id,roomNew);
    joinSocket(opponent.socket,roomNew,first);
    joinSocket(socket,roomNew,second);
    safeAck(ack,{ok:true,status:'matched',code:id,token:second.token,color:second.color,time});
    opponent.socket.emit('matchmaking:found',{code:id,token:first.token,color:first.color,time});
    broadcast(roomNew);queueBroadcast();
   }catch(e){safeAck(ack,{ok:false,error:String(e.message||e)});}
  });
  socket.on('matchmaking:cancel',(_payload={},ack)=>{
   const removed=queueRemove(socket.id);
   safeAck(ack,{ok:true,cancelled:removed});
   if(removed)queueBroadcast();
  });
  roomEvent(socket,'room:move',(room,seat,payload,ack)=>{
   refreshClock(room);
   if(!room.started||room.result){broadcast(room);throw Error('Match has not started or is finished');}
   if(seat.color!==room.chess.turn())throw Error('Not your turn');
   const from=String(payload.from||''),to=String(payload.to||'');
   if(!/^[a-h][1-8]$/.test(from)||!/^[a-h][1-8]$/.test(to))throw Error('Invalid square');
   const promotion=String(payload.promotion||'q').toLowerCase();
   if(!/^[qrbn]$/.test(promotion))throw Error('Invalid promotion');
   let move;
   try{move=room.chess.move({from,to,promotion});}catch{throw Error('Illegal move');}
   if(!move)throw Error('Illegal move');
   room.timeLeft[seat.color]+=room.increment;
   room.activeSince=Date.now();room.drawOffer=null;
   if(room.chess.isGameOver()){
    room.result={winner:room.chess.isCheckmate()?seat.color:null,reason:room.chess.isCheckmate()?'checkmate':room.chess.isStalemate()?'stalemate':'draw'};
    room.activeSince=null;
   }
   safeAck(ack,{ok:true,san:move.san});
   broadcast(room);
  });
  roomEvent(socket,'room:resign',(room,seat,_payload,ack)=>{
   if(!room.started||room.result)throw Error('No active game');
   room.result={winner:seat.color==='w'?'b':'w',reason:'resignation'};
   room.activeSince=null;safeAck(ack,{ok:true});broadcast(room);
  });
  roomEvent(socket,'room:draw',(room,seat,payload,ack)=>{
   if(!room.started||room.result)throw Error('No active game');
   const action=payload.action;
   if(action==='offer'){if(room.drawOffer&&room.drawOffer!==seat.color)throw Error('Answer the draw offer first');room.drawOffer=seat.color;}
   else if(action==='accept'){
    if(room.drawOffer===null||room.drawOffer===seat.color)throw Error('No opposing draw offer');
    room.result={winner:null,reason:'agreement'};room.drawOffer=null;room.activeSince=null;
   }else if(action==='decline'){if(room.drawOffer===seat.color||!room.drawOffer)throw Error('No opposing draw offer');room.drawOffer=null;}
   else throw Error('Invalid draw action');
   safeAck(ack,{ok:true});broadcast(room);
  });
  roomEvent(socket,'room:rematch',(room,seat,_payload,ack)=>{
   if(!room.result)throw Error('Finish the game first');
   seat.rematch=true;
   if(room.players.every(p=>p?.rematch)){
    room.chess=new Chess();room.timeLeft={w:room.base,b:room.base};
    room.activeSince=Date.now();room.result=null;room.drawOffer=null;
    room.players.forEach(p=>p.rematch=false);
   }
   safeAck(ack,{ok:true});broadcast(room);
  });
  socket.on('disconnect',()=>{
   if(queueRemove(socket.id))queueBroadcast();
   const room=rooms.get(socket.data.roomId),player=getSeat(room,socket);
   if(player){player.socket=null;broadcast(room);}
  });
 });
 const ticker=setInterval(()=>{
  const now=Date.now();
  for(const room of rooms.values()){
   if(now-room.updated>2*60*60*1000){rooms.delete(room.id);continue;}
   if(room.started&&!room.result){refreshClock(room);broadcast(room,{touch:false});}
  }
 },1000);
 ticker.unref?.();
 return new Promise((resolveStart,reject)=>{
  httpServer.once('error',reject);
  httpServer.listen(port,host,()=>{
   httpServer.off('error',reject);
   resolveStart({port:httpServer.address().port,httpServer,io,rooms,queues,waiting,
    close:async()=>{clearInterval(ticker);await new Promise(r=>io.close(r));}});
  });
 });
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 createGameServer().then(x=>console.log('RookVanta running at http://localhost:'+x.port))
  .catch(e=>{console.error(e);process.exitCode=1;});
}
