(()=>{
 'use strict';const C=window.HunorGdacsCore,states=new Map();let generation=0;
 const colors={Green:'#159447',Orange:'#e58a12',Red:'#d73038',Unknown:'#64748b'};
 async function mount(root){
  if(states.has(root))return;const state={map:null,abort:null};states.set(root,state);
  const mapNode=root.querySelector('[data-gdacs-map]'),status=root.querySelector('[data-gdacs-status]'),button=root.querySelector('[data-gdacs-refresh]'),select=root.querySelector('select'),list=root.querySelector('[data-gdacs-list]');let rows=[],layer;
  function paint(){if(!root.isConnected)return;const filtered=rows.filter(r=>!select.value||r.type===select.value);list.replaceChildren();layer?.clearLayers();
   for(const row of filtered){const link=document.createElement('a');link.href=row.url;link.target='_blank';link.rel='noopener noreferrer';link.textContent=C.types[row.type]+' · '+row.title;const li=document.createElement('li');li.append(link);list.append(li);
    const popup=document.createElement('div'),title=document.createElement('strong'),a=document.createElement('a');title.textContent=row.title;a.href=row.url;a.target='_blank';a.rel='noopener noreferrer';a.textContent='Részletek a GDACS oldalán ↗';popup.append(title,document.createElement('br'),a);
    window.L.circleMarker([row.lat,row.lon],{radius:7,color:colors[row.level],fillOpacity:.8,weight:2}).bindPopup(popup).addTo(layer);
   }
  }
  try{if(!window.L)throw Error('A térkép nem tölthető be.');state.map=window.L.map(mapNode,{scrollWheelZoom:false}).setView([20,10],2);window.L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:18,attribution:'© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a> közreműködők'}).addTo(state.map);layer=window.L.layerGroup().addTo(state.map);}catch{status.textContent='A térkép most nem érhető el. A GDACS az alábbi hivatkozással megnyitható.';return;}
  async function load(){const g=++generation;state.abort?.abort();state.abort=new AbortController();button.disabled=true;status.textContent='GDACS-események betöltése…';
   const timeout=setTimeout(()=>state.abort.abort(),15000);
   try{const results=await Promise.allSettled(Object.keys(C.types).map(async type=>{const r=await fetch('/api/gdacs/'+type,{credentials:'omit',signal:state.abort.signal,headers:{Accept:'application/geo+json, */*;q=0.8'}});if(!r.ok)throw Error('upstream');const text=await r.text();if(text.length>4000000)throw Error('size');return C.normalize(JSON.parse(text),type);}));if(!root.isConnected||g!==generation)return;
    const good=results.filter(r=>r.status==='fulfilled');if(!good.length)throw Error('upstream');rows=good.flatMap(r=>r.value);paint();const dates=rows.map(r=>r.updated).filter(Boolean);status.textContent=(good.length<6?'Részleges adatbetöltés. ':'')+rows.length+' esemény · Lekérdezve: '+new Intl.DateTimeFormat('hu-HU',{dateStyle:'short',timeStyle:'short'}).format(new Date())+(dates.length?' · Legfrissebb forrásadat: '+new Intl.DateTimeFormat('hu-HU',{dateStyle:'short',timeStyle:'short'}).format(Math.max(...dates)):'')+'. A forrás dátumai az események részleteinél ellenőrizhetők.';
   }catch{if(root.isConnected&&g===generation)status.textContent='A GDACS adatai most nem tölthetők be. A korábban betöltött adatok elavulhatnak. Próbáld újra vagy nyisd meg a forrást.';}finally{clearTimeout(timeout);if(root.isConnected)button.disabled=false;}
  }
  select.addEventListener('change',paint);button.addEventListener('click',load);load();
 }
 const observer=new MutationObserver(()=>{for(const [root,state]of states){if(!root.isConnected){state.abort?.abort();state.map?.remove();states.delete(root);}}document.querySelectorAll('[data-gdacs-panel]').forEach(mount);});observer.observe(document.body,{childList:true,subtree:true});document.querySelectorAll('[data-gdacs-panel]').forEach(mount);
})();
