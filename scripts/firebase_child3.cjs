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
 if(live.buildVersion!=='3'||live.displayVersion!=='1.0.3')throw new Error('version-mismatch');
 const notes='Child Safety build3: paired device opens Home without another parent login, preserved encrypted pairing, new family shield icon. Dashboard remembers public key and keeps sign-in via protected HttpOnly Secure session cookie; passwords are not stored. Start Tracking remains manual. Free hosting and foreground timer are for testing, not emergency protection.';
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}?updateMask=releaseNotes.text`,'PATCH',{releaseNotes:{text:notes}});
 await request(`https://firebaseappdistribution.googleapis.com/v1/${release.name}:distribute`,'POST',{testerEmails:['frances09f@gmail.com']});
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-child3-result.json',JSON.stringify({app_id:app,sha256:'536554951b60125ff2caaea456fbdedf0096d94e495054924e681dd3158a92e0',release:live},null,2));
})().catch(()=>{console.error('Firebase distribution or live verification failed');process.exit(1)});
