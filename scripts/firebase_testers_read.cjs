const fs=require('fs');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
const r=await c.request({url:'https://firebaseappdistribution.googleapis.com/v1/projects/509368336413/testers',params:{pageSize:100},timeout:30000});
const allowed=(r.data.testers||[]).filter(t=>t.name.endsWith('/testers/frances09f@gmail.com')).map(t=>({name:t.name,displayName:t.displayName,lastActivityTime:t.lastActivityTime}));
fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-testers-read.json',JSON.stringify({matching:allowed,total:(r.data.testers||[]).length,nextPage:!!r.data.nextPageToken},null,2));
})().catch(e=>{console.error('Tester API read failed:'+e.response?.status);process.exit(1)});
