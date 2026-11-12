/* Facade over the same API; no tokens are returned to the quiz frame. */
window.HunorQuizRemoteService={create({session=async()=>null,fetcher=fetch,onAuthChange=()=>{}}={}){
 const transport=HunorQuizMemberTransport.create({session,fetcher,allowGuest:true}),listeners=new Set();let revision=0;
 onAuthChange(()=>{revision++;transport.logout();for(const listener of listeners)listener();});
 return Object.freeze({
  async context(){const before=revision,identity=await session();
   try{const response=await fetcher('/api/public-quiz/metadata',{credentials:'omit',cache:'no-store',signal:AbortSignal.timeout(8000)});if(!response.ok||before!==revision)return {enabled:false};
    const m=await response.json();if(before!==revision)return {enabled:false};
    return {enabled:m.enabled===true&&m.kiosk_supported===true&&typeof m.privacy_text==='string'&&m.privacy_text.length>=100,loggedIn:!!identity?.userId,noticeVersion:m.notice_version,retentionDays:m.retention_days,privacyText:m.privacy_text,controllerName:m.controller_name};
   }catch{return {enabled:false};}
  },request:transport.request,
  subscribe(listener){listeners.add(listener);return ()=>listeners.delete(listener);}
 });
}};
