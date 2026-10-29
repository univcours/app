// Update the downloaded comptage workbook in the browser until the API's
// server-side Excel release catches up. The existing API emits stored (method 0) ZIPs.
// If the format changes, keep the original download intact rather than corrupting it.
const cxEncoder = new TextEncoder();
const cxDecoder = new TextDecoder();
const cxXml = value => String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&apos;');
const cxAgency = name => {
  const match = /^(.*?) — tournée de distribution (10|[1-9])$/.exec(name || '');
  return match ? match[1] + ' T' + match[2] : name;
};

function cxReadZip(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const u16 = at => view.getUint16(at,true), u32 = at => view.getUint32(at,true);
  let end = -1;
  for (let p = bytes.length-22; p >= Math.max(0,bytes.length-65557); --p) {
    if (u32(p) === 0x06054b50 && p+22+u16(p+20) === bytes.length) { end=p; break; }
  }
  if (end<0) throw new Error('XLSX non reconnu');
  const length=u16(end+10), entries=[], directory=u32(end+16);
  let cursor=directory;
  for(let i=0;i<length;i++){
    if(u32(cursor)!==0x02014b50) throw new Error('Répertoire XLSX invalide');
    const method=u16(cursor+10),size=u32(cursor+20),nameLength=u16(cursor+28),extra=u16(cursor+30),comment=u16(cursor+32),offset=u32(cursor+42);
    const name=cxDecoder.decode(bytes.subarray(cursor+46,cursor+46+nameLength));
    if(method!==0 || u32(offset)!==0x04034b50) throw new Error('Compression XLSX non prise en charge');
    const from=offset+30+u16(offset+26)+u16(offset+28);
    entries.push({name,data:bytes.slice(from,from+size)});
    cursor+=46+nameLength+extra+comment;
  }
  return entries;
}
function cxCRC(bytes) {
 let crc=0xffffffff;
 for (const byte of bytes) {
   crc^=byte;
   for(let n=0;n<8;n++)crc=(crc>>>1) ^ ((crc&1)?0xedb88320:0);
 }
 return (crc^0xffffffff)>>>0;
}
function cxConcat(parts) {
 const total=parts.reduce((n,part)=>n+part.length,0),out=new Uint8Array(total);
 let pos=0;for(const part of parts){out.set(part,pos);pos+=part.length;}return out;
}
function cxWriteZip(entries){
 const locals=[],central=[];let offset=0;
 for(const entry of entries){
   const name=cxEncoder.encode(entry.name),data=entry.data,crc=cxCRC(data);
   const local=new Uint8Array(30+name.length),head=new DataView(local.buffer);
   head.setUint32(0,0x04034b50,true);head.setUint16(4,20,true);head.setUint16(6,0x800,true);head.setUint16(12,0x21,true);
   head.setUint32(14,crc,true);head.setUint32(18,data.length,true);head.setUint32(22,data.length,true);head.setUint16(26,name.length,true);local.set(name,30);
   const centralHead=new Uint8Array(46+name.length),ch=new DataView(centralHead.buffer);
   ch.setUint32(0,0x02014b50,true);ch.setUint16(4,20,true);ch.setUint16(6,20,true);ch.setUint16(8,0x800,true);ch.setUint16(14,0x21,true);
   ch.setUint32(16,crc,true);ch.setUint32(20,data.length,true);ch.setUint32(24,data.length,true);ch.setUint16(28,name.length,true);ch.setUint32(42,offset,true);centralHead.set(name,46);
   locals.push(local,data);central.push(centralHead);offset+=local.length+data.length;
 }
 const directory=cxConcat(central),end=new Uint8Array(22),e=new DataView(end.buffer);
 e.setUint32(0,0x06054b50,true);e.setUint16(8,entries.length,true);e.setUint16(10,entries.length,true);
 e.setUint32(12,directory.length,true);e.setUint32(16,offset,true);
 return cxConcat([...locals,directory,end]);
}

export async function conciseCountWorkbook(blob, submissions) {
 try {
   if (!submissions.length) return blob;
   const entries=cxReadZip(new Uint8Array(await blob.arrayBuffer()));
   let changed=false;
   for(let index=0;index<submissions.length;index++){
     const originalName=submissions[index].agency;
     const shortName=cxAgency(originalName);
     if(shortName===originalName)continue;
     const sheet=entries.find(entry=>entry.name===`xl/worksheets/sheet${index+1}.xml`);
     if(!sheet)continue;
     let xml=cxDecoder.decode(sheet.data);
     const cell=/<x:c\b[^>]*\br="A1"[^>]*(?:\/>|>[\s\S]*?<\/x:c>)/.exec(xml);
     if(!cell)continue;
     const style=/\bs="(\d+)"/.exec(cell[0])?.[1];
     const replacement=`<x:c r="A1"${style?` s="${style}"`:''} t="inlineStr"><x:is><x:t xml:space="preserve">${cxXml(shortName)}</x:t></x:is></x:c>`;
     xml=xml.replace(cell[0],replacement);
     sheet.data=cxEncoder.encode(xml);changed=true;
   }
   if(!changed)return blob;
   const workbook=entries.find(entry=>entry.name==='xl/workbook.xml');
   if(workbook){
     let pos=0,xml=cxDecoder.decode(workbook.data);
     xml=xml.replace(/<x:sheet\b[^>]*\/>/g,tag=>{
       const identity=submissions[pos++];
       if(!identity)return tag;
       const name=cxAgency(identity.agency);
       return tag.replace(/\bname="[^"]*"/,`name="${cxXml(name.slice(0,31))}"`);
     });
     workbook.data=cxEncoder.encode(xml);
   }
   return new Blob([cxWriteZip(entries)],{type:blob.type||'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
 }catch(error){
   console.warn('Mise à jour de l’intitulé de tournée indisponible ; téléchargement original conservé.',error);
   return blob;
 }
}
