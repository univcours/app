import {cpSync,rmSync,mkdirSync} from 'node:fs';
rmSync('dist',{recursive:true,force:true});mkdirSync('dist',{recursive:true});cpSync('web','dist',{recursive:true});
console.log('NovaGrid dist/ ready');
