const fs=require('fs');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
 const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const app='projects/509368336413/apps/1:509368336413:android:6dcc26c92c2e85f40a46f4';
 const request=async(url,method='GET',data,headers={})=>(await c.request({url,method,data,headers,timeout:90000})).data;
 let op=await request(`https://firebaseappdistribution.googleapis.com/upload/v1/${app}/releases:upload`,'POST',fs.readFileSync(process.env.RUNNER_TEMP+'/Replier.apk'),{'X-Goog-Upload-Protocol':'raw','X-Goog-Upload-File-Name':'Replier.apk','Content-Type':'application/octet-stream'});
 for(let i=0;!op.done&&i<90;i++){await new Promise(r=>setTimeout(r,3000));op=await request(`https://firebaseappdistribution.googleapis.com/v1/${op.name}`)}
 if(!op.done||op.error)throw new Error('upload-failed');
 const release=op.response?.release;if(!release?.name)throw new Error('missing-release');
 const live=await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}`);
 if(live.buildVersion!=='16'||live.displayVersion!=='1.0.16')throw new Error('version-mismatch');
 const notes='Replier16 working-engine/UI port. Starts OFF, confirmation ON. Runtime encrypted provider keys. Confirmation expiry cancels. Unsafe accessibility sending disabled. Previous v15 history preserved. Phone sending/background/model performance requires testing.';
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}?updateMask=releaseNotes.text`,'PATCH',{releaseNotes:{text:notes}});
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-replier16-result.json',JSON.stringify({app_id:app,sha256:'cdfcdc97535c076cbe46ddd6fb8534aa8dce928d6ae532906a27f153d58d32f8',release:live},null,2));
})().catch(()=>{console.error('Firebase distribution or live verification failed');process.exit(1)});
