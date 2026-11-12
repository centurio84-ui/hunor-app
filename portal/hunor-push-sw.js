self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('push',event=>{
 let data={};try{data=event.data?.json()||{};}catch{}
 const alertId=typeof data.eventId==='string'&&/^[0-9a-f-]{36}$/i.test(data.eventId)?data.eventId:null;
 event.waitUntil((async()=>{await self.registration.showNotification(typeof data.title==='string'?data.title:'HUNOR értesítés',{
  body:typeof data.body==='string'?data.body:'Új HUNOR értesítés érkezett.',
  icon:'/hunor-app-icon.svg',badge:'/hunor-app-icon.svg',tag:typeof data.tag==='string'?data.tag:'hunor-notification',
  requireInteraction:Boolean(alertId),vibrate:alertId?[300,120,300,120,800]:undefined,
  data:{url:alertId?'/?hunorAlert='+encodeURIComponent(alertId)+'#events':'/#profile'}
 });
 if(alertId){const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});for(const client of windows)client.postMessage({type:'HUNOR_ALERT_RECEIVED',eventId:alertId});}
 if(typeof data.receiptToken==='string'&&/^[0-9a-f]{64}$/.test(data.receiptToken)&&typeof data.testRunId==='string'&&/^[0-9a-f-]{36}$/i.test(data.testRunId)){try{await fetch('https://embicteneumubwlqqfik.supabase.co/functions/v1/hunor-web-push',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'receipt',runId:data.testRunId,receiptToken:data.receiptToken}),signal:AbortSignal.timeout(6000)});}catch{}}
 if(typeof data.testRunId==='string'&&/^[0-9a-f-]{36}$/i.test(data.testRunId)){const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});for(const client of windows)client.postMessage({type:'HUNOR_PUSH_TEST_RECEIVED',runId:data.testRunId});}
 })());
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();
 event.waitUntil((async()=>{
  let target=new URL('/#profile',self.location.origin);
  try{const requested=new URL(event.notification.data?.url||'/#profile',self.location.origin);if(requested.origin===self.location.origin&&requested.pathname==='/')target=requested;}catch{}
  const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  const existing=windows.find(w=>new URL(w.url).origin===self.location.origin);
  if(existing){await existing.navigate(target.href);return existing.focus();}return self.clients.openWindow(target.href);
 })());
});
