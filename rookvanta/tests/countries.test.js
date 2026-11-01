import test from 'node:test';
import assert from 'node:assert/strict';
import {COUNTRY_CODES,normalizeCountry,countryFlag,countryName} from '../public/countries.js';
test('national flags cover all ISO countries and territories without duplicates',()=>{
 assert.ok(COUNTRY_CODES.length>=240);
 assert.equal(new Set(COUNTRY_CODES).size,COUNTRY_CODES.length);
 for(const code of ['MA','FR','US','BR','JP','AU','IN','ZA'])assert.ok(COUNTRY_CODES.includes(code));
});
test('players choose a valid flag; no flag is inferred or forged',()=>{
 assert.equal(normalizeCountry(' ma '),'MA');
 assert.equal(normalizeCountry('zz'),'');
 assert.equal(normalizeCountry('<script>'),'');
 assert.equal(normalizeCountry({value:'MA'}),'');
 assert.equal(countryFlag('MA'),'🇲🇦');
 assert.equal(countryFlag('FR'),'🇫🇷');
 assert.equal(countryFlag(''),'🌐');
});
test('country names are localized from ISO region codes',()=>{
 assert.match(countryName('MA','en'),/Morocco/);
 assert.equal(typeof countryName('JP','ar'),'string');
 assert.equal(countryName(null),'International');
});
