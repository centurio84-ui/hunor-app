/* Transport for the existing quiz API. No auth SDK, second engine or local scoring. */
(function(scope){
 'use strict';
 function create({session,fetcher=fetch,allowGuest=false,timeoutMs=10000}){
  if(!Number.isFinite(timeoutMs)||timeoutMs<=0)throw Error('Érvénytelen hálózati időkorlát.');
  let owner=null,csrf='',generation=0,controller=new AbortController(),busy=false;
  const reset=()=>{generation++;controller.abort();controller=new AbortController();owner=null;csrf='';busy=false;};
  async function request(action,data={}){
   if(!['start','next','answer','finish','my_results'].includes(action))throw Error('Nem támogatott kvízművelet.');
   if(busy)throw Error('Várd meg az előző kérés végét.');
   const initial=generation;const identity=await session();
   if(initial!==generation)throw new DOMException('A fiók megváltozott.','AbortError');
   if((!identity?.userId||!identity.accessToken)&&(!allowGuest||action==='my_results'))throw Error('Tagi belépés szükséges.');
   if(busy)throw Error('Várd meg az előző kérés végét.');
   const identityKey=identity?.userId||'guest';if(owner && owner!==identityKey)reset();owner=identityKey;
   const current=generation,signal=controller.signal;busy=true;
   const check=()=>{if(current!==generation)throw new DOMException('A fiók megváltozott.','AbortError');};
   const post=async(a,payload)=>{
    const requestAbort=new AbortController(),abort=()=>requestAbort.abort();
    if(signal.aborted)abort();else signal.addEventListener('abort',abort,{once:true});
    const timer=setTimeout(()=>requestAbort.abort(new DOMException('A szerver nem válaszolt időben. A művelet még nem igazolt.','TimeoutError')),timeoutMs);
    const checkRequest=()=>{check();if(requestAbort.signal.aborted)throw requestAbort.signal.reason;};
    try{
     const response=await fetcher('/api/public-quiz/'+a,{method:'POST',credentials:'same-origin',cache:'no-store',signal:requestAbort.signal,headers:{'Content-Type':'application/json',...(identity?.accessToken?{Authorization:'Bearer '+identity.accessToken}:{}),...(csrf?{'X-LRC-CSRF':csrf}:{})},body:JSON.stringify(payload)});
     checkRequest();let result;try{result=await response.json();}catch{throw Error('A kvíz válasza nem olvasható.');}checkRequest();
     if(!response.ok||result?.error)throw Error(result?.error||'A szerver nem igazolta a műveletet.');return result;
    }finally{clearTimeout(timer);signal.removeEventListener('abort',abort);}
   };
   try{
    if(!csrf){const boot=await post('bootstrap',{});if(typeof boot.csrf!=='string')throw Error('A kvíz munkamenete nem indítható.');csrf=boot.csrf;}
    const result=await post(action,data);check();return result;
   }finally{if(current===generation)busy=false;}
  }
  return {request,logout:reset};
 }
 const api={create};if(typeof module==='object'&&module.exports)module.exports=api;else scope.HunorQuizMemberTransport=api;
})(typeof window==='undefined'?globalThis:window);
