/* Shared supporter header: no account access, API requests, timers or tracking. */
(()=>{
 const id='hunor-mad-supporter';
 function mount(){
  if(document.getElementById(id))return;
  const host=document.querySelector('.app > main')||document.querySelector('body > main')||document.body;
  const footer=document.createElement('section');footer.id=id;footer.className='hunor-supporter';footer.setAttribute('aria-label','Támogatónk');
  const line=document.createElement('span');line.className='hunor-supporter__rule';line.setAttribute('aria-hidden','true');
  const label=document.createElement('span');label.className='hunor-supporter__label';label.textContent='Támogatónk';
  const brand=document.createElement('span');brand.className='hunor-supporter__brand';
  const logo=document.createElement('img');logo.className='hunor-supporter__logo';logo.src='/supporter/mad-logo.png';logo.alt='MAD – támogató';logo.width=176;logo.height=58;logo.loading='eager';logo.decoding='async';
  brand.append(logo);footer.append(line,label,brand);host.prepend(footer);
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount,{once:true});else mount();
 // Portal routes replace #content; the footer lives outside it. Recovery alone
 // replaces the body, so reattach once on actual removal, without polling.
 new MutationObserver(()=>{if(!document.getElementById(id))mount();}).observe(document.documentElement,{childList:true,subtree:true});
})();
