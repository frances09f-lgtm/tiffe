const fs=require('fs');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
 const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const r=await c.request({url:'https://firebaseappdistribution.googleapis.com/v1/projects/509368336413/testers',params:{pageSize:100},timeout:30000});
 if(!(r.data.testers||[]).some(t=>t.name.endsWith('/testers/frances09f@gmail.com')))throw Error('existing-tester-missing');
 const targets=[{name:'projects/509368336413/apps/1:509368336413:android:6dcc26c92c2e85f40a46f4/releases/3mj7a2fd0uk48',version:'18'},{name:'projects/509368336413/apps/1:509368336413:android:664d240443b77a5a0a46f4/releases/37amus6vqlj2o',version:'3'}];
 const results=[];
 for(const t of targets){
 const live=(await c.request({url:'https://firebaseappdistribution.googleapis.com/v1/'+t.name,timeout:30000})).data;
 if(live.buildVersion!==t.version)throw Error('version-mismatch');
 await c.request({url:'https://firebaseappdistribution.googleapis.com/v1/'+t.name+':distribute',method:'POST',data:{testerEmails:['frances09f@gmail.com']},timeout:30000});
 results.push({release:t.name,buildVersion:live.buildVersion,testingUri:live.testingUri,recipient:'frances09f@gmail.com',distributed:true});
 }
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-new-app-distribute.json',JSON.stringify({results},null,2));
})().catch(e=>{console.error('Distribution failed:'+e.response?.status);process.exit(1)});
