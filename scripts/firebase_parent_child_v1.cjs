const fs=require('fs');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
 const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const app=process.env.FIREBASE_APP_RESOURCE;
 const apk=process.env.RUNNER_TEMP+'/App.apk';
 const request=async(url,method='GET',data,headers={})=>(await c.request({url,method,data,headers,timeout:90000})).data;
 let op=await request(`https://firebaseappdistribution.googleapis.com/upload/v1/${app}/releases:upload`,'POST',fs.readFileSync(apk),{'X-Goog-Upload-Protocol':'raw','X-Goog-Upload-File-Name':'App.apk','Content-Type':'application/octet-stream'});
 for(let i=0;!op.done&&i<90;i++){await new Promise(r=>setTimeout(r,3000));op=await request(`https://firebaseappdistribution.googleapis.com/v1/${op.name}`)}
 if(!op.done||op.error)throw new Error('upload-failed');
 const release=op.response?.release;if(!release?.name)throw new Error('missing-release');
 const live=await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}`);
 if(live.buildVersion!==process.env.EXPECTED_BUILD||live.displayVersion!==process.env.EXPECTED_VERSION)throw new Error('version-mismatch');
 const notes=process.env.RELEASE_NOTES;
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}?updateMask=releaseNotes.text`,'PATCH',{releaseNotes:{text:notes}});
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}:distribute`,'POST',{testerEmails:['frances09f@gmail.com']});
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-'+process.env.RESULT_NAME+'-result.json',JSON.stringify({app_id:app,sha256:process.env.EXPECTED_SHA,release:live},null,2));
})().catch(()=>{console.error('Firebase distribution or live verification failed');process.exit(1)});
