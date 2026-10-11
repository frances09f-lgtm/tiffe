const fs=require('fs');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
 const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const app='projects/509368336413/apps/1:509368336413:android:664d240443b77a5a0a46f4';
 const request=async(url,method='GET',data,headers={})=>(await c.request({url,method,data,headers,timeout:90000})).data;
 let op=await request(`https://firebaseappdistribution.googleapis.com/upload/v1/${app}/releases:upload`,'POST',fs.readFileSync(process.env.RUNNER_TEMP+'/Child.apk'),{'X-Goog-Upload-Protocol':'raw','X-Goog-Upload-File-Name':'Child.apk','Content-Type':'application/octet-stream'});
 for(let i=0;!op.done&&i<90;i++){await new Promise(r=>setTimeout(r,3000));op=await request(`https://firebaseappdistribution.googleapis.com/v1/${op.name}`)}
 if(!op.done||op.error)throw new Error('upload-failed');
 const release=op.response?.release;if(!release?.name)throw new Error('missing-release');
 const live=await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}`);
 if(live.buildVersion!=='2'||live.displayVersion!=='1.0.2')throw new Error('version-mismatch');
 const notes='Child Safety test build2: parent Firebase sign-in and write-only device pairing. Private family-only HTTPS backend. SOS flag persists, not police/SMS. Free hosting can sleep and tracking uses foreground timer. No emergency-service guarantee. Synthetic family isolation/SOS/privacy end-to-end tests passed; physical-phone/background testing pending.';
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}?updateMask=releaseNotes.text`,'PATCH',{releaseNotes:{text:notes}});
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-child2-result.json',JSON.stringify({app_id:app,sha256:'1a45784871429c4a5f7c11b78a0f9ad98bb9a0a27f08090dbca2c9074ef23ad0',release:live},null,2));
})().catch(()=>{console.error('Firebase distribution or live verification failed');process.exit(1)});
