const fs=require('fs'),crypto=require('crypto');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
const apk=process.env.APK_PATH,expected=process.env.EXPECTED_SHA256;
if(crypto.createHash('sha256').update(fs.readFileSync(apk)).digest('hex')!==expected)throw Error('hash');
const credential=JSON.parse(fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS));
if(credential.project_id!=='app-testing-2cdba'||credential.client_email!=='github-app-distribution@app-testing-2cdba.iam.gserviceaccount.com')throw Error('credential-account');
const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
const req=async(url,method='GET',data,headers)=> {try{return (await c.request({url,method,data,headers,timeout:60000})).data;}catch(e){console.error('API failed: '+method+' '+url.split('?')[0]+' status '+e.response?.status);throw e;}};
const base='https://firebase.googleapis.com/v1beta1',apps=base+'/projects/app-testing-2cdba/androidApps';
let all=[],pageToken;
do{const d=await req(apps+(pageToken?'?pageToken='+encodeURIComponent(pageToken):''));all.push(...(d.apps||[]));pageToken=d.nextPageToken;}while(pageToken);
let app=all.find(a=>a.packageName==='com.ambi.tiffe.staff');
if(process.env.STAFF_READ_ONLY==='true'){console.log('Read-only Staff app result: '+JSON.stringify(app?{appId:app.appId,packageName:app.packageName}:null));return;}
async function complete(op,base){for(let n=0;!op.done&&n<60;n++){await new Promise(r=>setTimeout(r,2000));op=await req(base+'/'+op.name);}if(op.error||!op.done)throw Error('operation');return op.response;}
if(!app)app=await complete(await req(apps,'POST',{packageName:'com.ambi.tiffe.staff',displayName:'Tiffe Staff'}),base);
if(app.packageName!=='com.ambi.tiffe.staff')throw Error('wrong-app');
const parent='projects/509368336413/apps/'+app.appId,dist='https://firebaseappdistribution.googleapis.com/v1/';
const before=await req(dist+parent+'/releases?pageSize=100');
if((before.releases||[]).some(r=>r.buildVersion==='6'))throw Error('v6-existing-release-reconcile-before-retry');
const uploaded=await req('https://firebaseappdistribution.googleapis.com/upload/v1/'+parent+'/releases:upload','POST',fs.createReadStream(apk),{'Content-Type':'application/octet-stream','X-Goog-Upload-Protocol':'raw','X-Goog-Upload-File-Name':'Tiffe-Staff.apk'});
const result=await complete(uploaded,'https://firebaseappdistribution.googleapis.com/v1');
const release=result.release;
if(!release||release.buildVersion!=='6'||release.displayVersion!=='1.0.6'||!release.name.startsWith(parent+'/releases/'))throw Error('uploaded-metadata');
const notes='Tiffe Staff v6: Upcoming orders list in Live Kitchen and newest-first All Orders. CI passed. Not tested on a phone.'+'\nAUDIT-SHA256:'+expected;
await req(dist+release.name+'?updateMask=releaseNotes.text','PATCH',{releaseNotes:{text:notes}});
const live=await req(dist+release.name);
if(!live.releaseNotes.text.includes('AUDIT-SHA256:'+expected))throw Error('notes-audit');
fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-staff-v6-result.json',JSON.stringify({app_id:app.appId,package_name:app.packageName,release_name:live.name,build_version:live.buildVersion,display_version:live.displayVersion,testing_uri:live.testingUri,firebase_console_uri:live.firebaseConsoleUri,sha256:expected,recipients:[],distributed:false,uploaded:true},null,2));
})().catch(e=>{console.error('Staff Firebase stopped; reconcile before retry. '+(e.response?.status||e.message));process.exit(1)});
