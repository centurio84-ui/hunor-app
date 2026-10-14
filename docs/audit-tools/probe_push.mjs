import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {stripTypeScriptTypes} from 'node:module';
const source=fs.readFileSync(new URL('../../supabase/functions/send-alert-push/index.ts',import.meta.url),'utf8');
const js=stripTypeScriptTypes(source,{mode:'strip'}).replace(/^import .*;\s*$/gm,'').replace('export default','globalThis.auditHandler =');
async function run({expired=false,status='active',table='alerts',repeat=1,provider='ok'}={}){
  const sent=[],removed=[],queries=[];
  class FakeJWT {setProtectedHeader(){return this}setIssuer(){return this}setSubject(){return this}setAudience(){return this}setIssuedAt(){return this}setExpirationTime(){return this}async sign(){return 'fake-oauth-assertion'}}
  const devices=[{id:'device-a',token:'fake-token-a',platform:'android'},{id:'device-b',token:'fake-token-b',platform:'ios'}];
  const ctx={supabaseAdmin:{from(t){
    queries.push(t);
    return {
      async select(){return {data:devices,error:null}},
      delete(){return {async eq(k,v){removed.push(v)}}}
    };
  }}};
  const sandbox={Response,Request,URLSearchParams,console:{error(){}},Deno:{env:{get(k){return ({FIREBASE_PROJECT_ID:'fake-project',FIREBASE_CLIENT_EMAIL:'test@example.invalid',FIREBASE_PRIVATE_KEY:'fake-private-key'})[k]}}},withSupabase:(_options,handler)=>handler,SignJWT:FakeJWT,importPKCS8:async()=>({}),fetch:async(url,options)=>{
    if(url==='https://oauth2.googleapis.com/token')return Response.json({access_token:'fake-oauth-token'});
    assert.match(url,/^https:\/\/fcm.googleapis.com\/v1\/projects\/fake-project\/messages:send$/);
    sent.push(JSON.parse(options.body));
    if(provider==='invalid')return Response.json({error:{details:[{errorCode:'INVALID_ARGUMENT'}]}},{status:400});
    if(provider==='unavailable')return Response.json({error:{status:'UNAVAILABLE'}},{status:503});
    return Response.json({name:'fake-message'});
  }};
  vm.runInNewContext(js,sandbox);
  const body={type:'INSERT',table,record:{id:'fake-alert',title:'Audit fixture',message:'No real notification',type:'alert',status,expires_at:expired?'2000-01-01T00:00:00Z':null}};
  let result;
  for(let i=0;i<repeat;i++){
    const response=await sandbox.auditHandler.fetch(new Request('https://example.invalid/audit',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}),ctx);
    result={status:response.status,body:await response.json()};
  }
  return {sent,removed,queries,result};
}
const findings=[];
let r=await run({status:'closed'});assert.equal(r.sent.length,0);findings.push('PASS: closed alerts ignored');
r=await run({table:'other'});assert.equal(r.sent.length,0);findings.push('PASS: unrelated webhook ignored');
r=await run();assert.equal(r.sent.length,2);findings.push('CONFIRMED GAP: all stored devices selected without recipient/member filtering');
r=await run({expired:true});assert.equal(r.sent.length,2);findings.push('CONFIRMED GAP: expired active alert still sent');
r=await run({repeat:2});assert.equal(r.sent.length,4);findings.push('CONFIRMED GAP: duplicate webhook repeats all sends');
r=await run({provider:'invalid'});assert.equal(r.removed.length,2);findings.push('CONFIRMED GAP: generic INVALID_ARGUMENT deletes tokens');
r=await run({provider:'unavailable'});assert.equal(r.result.status,200);assert.equal(r.result.body.sent,0);findings.push('CONFIRMED GAP: all-provider failures returned as HTTP 200, no durable retry in handler');
console.log(JSON.stringify({checks:findings.length,network:'fully mocked; no real push sent',auth:'withSupabase middleware mocked; its security was NOT tested',findings},null,2));
