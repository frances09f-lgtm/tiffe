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
 if(live.buildVersion!=='17'||live.displayVersion!=='1.0.17')throw new Error('version-mismatch');
 const notes='Replier17 Qwen download fix: model tile/arrow start downloading, visible errors, independent download queue, resume, GGUF exact size and SHA256 verification. Existing Llama model preserved. Phone download retest pending.';
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}?updateMask=releaseNotes.text`,'PATCH',{releaseNotes:{text:notes}});
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-replier17-result.json',JSON.stringify({app_id:app,sha256:'2f9c34ee4922adab90c7af2cf408ed3d9bd0bbee8d269d6cc939ec38d3bbad70',release:live},null,2));
})().catch(()=>{console.error('Firebase distribution or live verification failed');process.exit(1)});
