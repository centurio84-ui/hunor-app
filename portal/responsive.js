(()=>{
 if(window.hunorPasswordRecovery)return;
 const sidebar=document.querySelector('.app>.sidebar'),topbar=document.querySelector('.topbar');if(!sidebar||!topbar)return;
 sidebar.id='hunorMobileNavigation';
 const toggle=document.createElement('button');toggle.type='button';toggle.className='mobile-menu-toggle';toggle.textContent='☰';toggle.setAttribute('aria-label','Menü megnyitása');toggle.setAttribute('aria-controls',sidebar.id);toggle.setAttribute('aria-expanded','false');topbar.prepend(toggle);
 const close=document.createElement('button');close.type='button';close.className='mobile-menu-close';close.textContent='×';close.setAttribute('aria-label','Menü bezárása');sidebar.prepend(close);
 const backdrop=document.createElement('button');backdrop.type='button';backdrop.className='mobile-menu-backdrop';backdrop.tabIndex=-1;backdrop.setAttribute('aria-label','Menü bezárása');document.body.append(backdrop);
 const narrow=matchMedia('(max-width:1100px)');let focusBefore=null;
 function sync(){const opened=document.body.classList.contains('mobile-menu-open');if(narrow.matches&&!opened){sidebar.setAttribute('inert','');sidebar.setAttribute('aria-hidden','true');}else{sidebar.removeAttribute('inert');sidebar.removeAttribute('aria-hidden');}toggle.setAttribute('aria-expanded',String(opened));}
 function show(){focusBefore=document.activeElement;document.body.classList.add('mobile-menu-open');sync();close.focus();}
 function hide(returnFocus=true){document.body.classList.remove('mobile-menu-open');sync();if(returnFocus)(focusBefore?.isConnected?focusBefore:toggle).focus();}
 toggle.addEventListener('click',()=>document.body.classList.contains('mobile-menu-open')?hide():show());close.addEventListener('click',()=>hide());backdrop.addEventListener('click',()=>hide());
 sidebar.addEventListener('click',event=>{if(event.target.closest('[data-page],.brand-home,.profile-shortcut,#navLogout,#logout'))hide(false);});
 document.addEventListener('keydown',event=>{if(!document.body.classList.contains('mobile-menu-open'))return;if(event.key==='Escape'){event.preventDefault();hide();}if(event.key==='Tab'){const buttons=[...sidebar.querySelectorAll('button,a,input,select')].filter(el=>!el.disabled&&el.getClientRects().length),first=buttons[0],last=buttons.at(-1);if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}}});
 narrow.addEventListener('change',()=>{document.body.classList.remove('mobile-menu-open');sync();});sync();
 const content=document.querySelector('#content'),modal=document.querySelector('#modal');let scheduled=false;
 function wrapTables(){scheduled=false;document.querySelectorAll('#content table,#modal table').forEach(table=>{if(table.closest('.touch-table-wrap,.log-table-wrap,.log-table-scroll'))return;const wrap=document.createElement('div');wrap.className='touch-table-wrap';wrap.tabIndex=0;wrap.setAttribute('role','region');wrap.setAttribute('aria-label','Táblázat, vízszintesen görgethető');table.before(wrap);wrap.append(table);});}
 const observer=new MutationObserver(()=>{if(scheduled)return;scheduled=true;requestAnimationFrame(wrapTables);});if(content)observer.observe(content,{childList:true,subtree:true});if(modal)observer.observe(modal,{childList:true,subtree:true});wrapTables();
})();
