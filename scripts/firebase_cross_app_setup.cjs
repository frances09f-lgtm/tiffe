const fs=require('fs');
const {GoogleAuth}=require('../distribution/tooling/node_modules/google-auth-library');
(async()=>{
 const c=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const project='app-testing-2cdba',base='https://firebase.googleapis.com/v1beta1';
 const req=async(url,method='GET',data)=>{const r=await c.request({url,method,data,timeout:30000});return r.data};
 const report={project,apps:[],errors:[]};
 for(const spec of [{type:'androidApps',packageName:'com.ambi.replier',displayName:'Replier'},{type:'androidApps',packageName:'com.childsafety.child_safety_tracker',displayName:'Child Safety Tracker'},{type:'webApps',displayName:'Child Safety Parent Dashboard'}]){
  try{
   const url=`${base}/projects/${project}/${spec.type}`;
   const listed=await req(url);let app=(listed.apps||[]).find(a=>spec.packageName?a.packageName===spec.packageName:a.displayName===spec.displayName);
   if(!app){const {type,...data}=spec;let op=await req(url,'POST',data);for(let i=0;!op.done&&i<60;i++){await new Promise(r=>setTimeout(r,2000));op=await req(`${base}/${op.name}`)}if(op.error||!op.done)throw new Error('create-operation-failed');app=op.response;}
   const config=await req(`${base}/${app.name}/config`);
   report.apps.push({type:spec.type,app,config});
  }catch(e){report.errors.push({stage:spec.displayName,status:e.response?.status||null,message:'Firebase app access/setup failed'});}
 }
 try{
  const url=`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`;
  await req(url+'?updateMask=signIn.email.enabled,signIn.email.passwordRequired','PATCH',{signIn:{email:{enabled:true,passwordRequired:true}}});
  const config=await req(url);report.emailPasswordEnabled=config.signIn?.email?.enabled===true&&config.signIn?.email?.passwordRequired===true;
 }catch(e){report.errors.push({stage:'Email Password provider',status:e.response?.status||null,message:'Auth configuration access failed'});}
 fs.writeFileSync(process.env.RUNNER_TEMP+'/firebase-cross-app-result.json',JSON.stringify(report,null,2));
 console.log('Firebase setup complete; non-secret metadata in artifact');
})().catch(()=>{console.error('Firebase setup failed');process.exit(1)});
