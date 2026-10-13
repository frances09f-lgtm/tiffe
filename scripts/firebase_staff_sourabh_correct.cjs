const fs=require('fs');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
const base='https://firebaseappdistribution.googleapis.com/v1/',parent='projects/509368336413',name=parent+'/apps/1:509368336413:android:bd1d8a9e2943aaa40a46f4/releases/4jen5cl1mh8u0';
const req=async(path,method='GET',data)=> (await c.request({url:base+path,method,data,timeout:30000})).data;
const live=await req(name);
if(live.buildVersion!=='2'||live.displayVersion!=='1.0.2'||!live.releaseNotes?.text.includes('AUDIT-SHA256:f0fadd709d056696630c23667d1b264faf5d6aad5d95911c45c33c93e7f2cc3e'))throw Error('wrong-release');
await req(name+':distribute','POST',{testerEmails:['sourabhsutar2001@gmail.com']});
let found=null,page;
do{const r=await req(parent+'/testers?pageSize=100'+(page?'&pageToken='+encodeURIComponent(page):''));found=(r.testers||[]).find(t=>t.name.endsWith('/testers/sourabhsutar2001@gmail.com'))||found;page=r.nextPageToken;}while(page&&!found);
if(!found)throw Error('tester-not-found-after-distribution');
fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-sourabh-correction.json',JSON.stringify({release_name:name,testing_uri:live.testingUri,firebase_console_uri:live.firebaseConsoleUri,recipient:'sourabhsutar2001@gmail.com',distributed:true,tester_exists:true,last_activity_time:found.lastActivityTime||null,old_tester_removed:false},null,2));
})().catch(e=>{console.error('Correction stopped; reconcile before retry. '+(e.response?.status||e.message));process.exit(1)});
