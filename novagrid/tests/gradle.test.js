import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixProguardConfig} from '../scripts/fix-android-gradle.mjs';

test('migrates legacy Groovy ProGuard file',()=>{
 const result=fixProguardConfig("proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'");
 assert.equal(result.changes,1);
 assert.match(result.content,/getDefaultProguardFile\('proguard-android-optimize\.txt'\)/);
});
test('supports double quotes and whitespace',()=>{
 const result=fixProguardConfig('getDefaultProguardFile( "proguard-android.txt" )');
 assert.equal(result.changes,1);
 assert.equal(result.content,'getDefaultProguardFile("proguard-android-optimize.txt")');
});
test('idempotent on already-optimized configuration',()=>{
 const source="getDefaultProguardFile('proguard-android-optimize.txt')";
 const result=fixProguardConfig(source);
 assert.equal(result.changes,0);
 assert.equal(result.content,source);
});
test('fails safely if unsupported Gradle file layout is encountered',()=>{
 assert.throws(()=>fixProguardConfig('apply plugin: "com.android.application"'),/Could not locate/);
});
