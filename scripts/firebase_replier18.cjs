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
 if(live.buildVersion!=='18'||live.displayVersion!=='1.0.18')throw new Error('version-mismatch');
 const notes='Replier18 adds optional Cloudflare Workers AI, preserves Groq/Gemini/local providers; encrypted runtime token and Account ID setup required. No embedded keys. Live Cloudflare inference awaits user setup.';
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}?updateMask=releaseNotes.text`,'PATCH',{releaseNotes:{text:notes}});
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}:distribute`,'POST',{testerEmails:['frances09f@gmail.com']});
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-replier18-result.json',JSON.stringify({app_id:app,sha256:'cf92ab985612669250f12481af764ab3bb171d5d7c8fddb351183c09c9b372ae',release:live},null,2));
})().catch(()=>{console.error('Firebase distribution or live verification failed');process.exit(1)});
