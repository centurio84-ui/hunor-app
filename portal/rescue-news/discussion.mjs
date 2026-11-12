const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function safeUrl(value){try{const u=new URL(value);return ['http:','https:'].includes(u.protocol)&&!u.username&&!u.password?u.href:null;}catch{return null;}}
export async function openDiscussion({kind,id,api,modal,closeModal,actorId,isActive}){
 if(!['post','resource'].includes(kind)||!uuid.test(id)||!isActive())return;
 modal('<section class="rna rna-dialog rna-discussion"><h2>Belső hozzászólások</h2><p>Csak jóváhagyott csapattagoknak. Nem jelenik meg a vendégoldalon.</p><div data-comments></div><form class="rna-form"><label>Hozzászólás<textarea name="body" maxlength="2000"></textarea></label><label>Hivatkozás (nem kötelező)<input name="link_url" type="url" maxlength="2000" placeholder="https://…"></label><button type="submit">Hozzászólás küldése</button></form><p role="status" aria-live="polite"></p><button data-close>Bezárás</button></section>');
 const panel=document.querySelector('.rna-dialog'),form=panel.querySelector('form'),status=panel.querySelector('[role=status]');let busy=false;
 panel.querySelector('[data-close]').onclick=closeModal;
 const current=()=>panel.isConnected&&isActive();
 async function load(){const rows=await api('list',{kind,id});if(!current())return;
  panel.querySelector('[data-comments]').innerHTML=rows.map(x=>`<article class="rna-comment"><b>${esc(x.profiles?.name||'Csapattag')}</b> <small>${esc(new Date(x.created_at).toLocaleString('hu-HU'))}</small><p>${esc(x.body)}</p>${safeUrl(x.link_url)?`<a href="${esc(safeUrl(x.link_url))}" target="_blank" rel="noopener noreferrer">${esc(x.link_url)}</a>`:''}${x.author_id===actorId?`<button type="button" data-delete="${esc(x.id)}">Saját hozzászólás törlése</button>`:''}</article>`).join('')||'<p>Még nincs hozzászólás. Az első legyél te.</p>';
 }
 form.onsubmit=async e=>{e.preventDefault();if(busy||!current())return;const f=new FormData(form),body=String(f.get('body')||'').trim(),url=String(f.get('link_url')||'').trim();if((!body&&!url)||body.length>2000||url&&!safeUrl(url)){status.textContent='Adj meg szöveget és érvényes http/https hivatkozást.';return;}busy=true;form.querySelector('button').disabled=true;
  try{await api('insert',{kind,id,body,link_url:url});if(!current())return;form.reset();await load();status.textContent='Hozzászólás elküldve, csak belső használatra.';}catch{if(current())status.textContent='Nem sikerült elküldeni. Ellenőrizd a kapcsolatot és a tagságodat.';}finally{busy=false;if(current())form.querySelector('button').disabled=false;}
 };
 panel.querySelector('[data-comments]').onclick=async e=>{const button=e.target.closest('[data-delete]');if(!button||busy||!current())return;busy=true;try{await api('delete',{kind,id,commentId:button.dataset.delete});await load();}catch{if(current())status.textContent='A törlés nem sikerült.';}finally{busy=false;}};
 try{await load();}catch{if(current()){form.hidden=true;status.textContent='A beszélgetés nem érhető el. Lehet, hogy a bejegyzést elrejtették vagy megszűnt a hozzáférésed.';}}
}
