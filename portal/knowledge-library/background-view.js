'use strict';
window.HunorBackgroundView={mount({root,adapter}){
 const C=window.HunorBackgroundCore,actor=adapter.identity(),events=new AbortController();let alive=true,revision=0;
 const active=()=>alive&&actor&&adapter.identity()===actor;
 const on=(el,type,fn)=>el.addEventListener(type,fn,{signal:events.signal});
 root.replaceChildren();const panel=document.createElement('section');panel.className='panel kb-page';root.append(panel);
 const title=document.createElement('h1');title.textContent='Háttéranyagok';panel.append(title);
 const note=document.createElement('p');note.textContent='Az anyagok Google Drive-ban nyílnak meg. A szerkesztéshez külön Google-hozzáférés szükséges. A tagoknak láthatóvá tétel csak a honlapos megjelenést változtatja.';panel.append(note);
 const status=document.createElement('p');status.setAttribute('role','status');panel.append(status);
 const list=document.createElement('div');list.className='kb-folders';panel.append(list);
 const refresh=document.createElement('button');refresh.className='secondary';refresh.textContent='Frissítés';panel.append(refresh);
 if(C.manager(actor)&&adapter.create){
  const form=document.createElement('form');form.className='kb-editor';
  const heading=document.createElement('h2');heading.textContent='Almappa hozzáadása';form.append(heading);
  const nameLabel=document.createElement('label');nameLabel.textContent='Mappa neve';const name=document.createElement('input');name.required=true;name.maxLength=200;nameLabel.append(name);form.append(nameLabel);
  const urlLabel=document.createElement('label');urlLabel.textContent='Google Drive-mappa hivatkozása';const url=document.createElement('input');url.required=true;url.type='url';urlLabel.append(url);form.append(urlLabel);
  const save=document.createElement('button');save.type='submit';save.className='secondary';save.textContent='Mentés · csak kezelőknek';form.append(save);panel.append(form);
  on(form,'submit',async event=>{event.preventDefault();if(!active())return;save.disabled=true;try{await adapter.create(C.folder({title:name.value,url:url.value}));if(active()){form.reset();await load();}}catch(error){if(active())status.textContent=error.message||'A mentés sikertelen.';}finally{if(active())save.disabled=false;}});
 }
 async function load(){const request=++revision;status.textContent='Betöltés…';list.replaceChildren();try{const rows=await adapter.list();if(!active()||request!==revision)return;for(const row of rows){if(!C.canRead(actor,row))continue;const card=document.createElement('article');card.className='kb-item';const heading=document.createElement('h2');heading.textContent=row.title;card.append(heading);const label=document.createElement('p');label.textContent=row.visibility==='members'?'Tagok számára elérhető':'Csak admin és tagkezelő';card.append(label);const link=document.createElement('a');link.href=C.driveFolder(row.url);link.target='_blank';link.rel='noopener noreferrer';link.className='public-link';link.textContent='Mappa megnyitása ↗';card.append(link);if(actor.admin&&!row.is_root){const button=document.createElement('button');button.className='secondary';button.textContent=row.visibility==='members'?'Visszavonás a tagoktól':'Láthatóvá tétel a tagoknak';on(button,'click',async()=>{if(!active())return;button.disabled=true;try{await adapter.setVisibility(C.publish(actor,row.id,row.visibility!=='members'));if(active())await load();}catch(error){if(active()){status.textContent=error.message||'A módosítás sikertelen.';button.disabled=false;}}});card.append(button);}list.append(card);}status.textContent=list.children.length?'':'Nincs hozzáférhető háttéranyag.';}catch(error){if(active()&&request===revision)status.textContent=error.message||'A háttéranyagok nem tölthetők be.';}}
 on(refresh,'click',load);load();return {destroy(){alive=false;revision++;events.abort();root.replaceChildren();}};
}};

