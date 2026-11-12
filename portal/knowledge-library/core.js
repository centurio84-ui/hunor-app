(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.HunorKnowledgeCore=api;})(typeof window==='object'?window:globalThis,()=>{
 'use strict';
 const categories=Object.freeze({links:'Tudástár – Hasznos linkek',pdfs:'Tudástár – PDF-dokumentumok'});
 const routes=Object.freeze({knowledge:null,'knowledge-links':'links','knowledge-pdfs':'pdfs','knowledge-lectures':'lectures'});
 const collator=new Intl.Collator('hu',{sensitivity:'base',ignorePunctuation:true});
 const menu=Object.freeze([
  {route:'education',label:'Oktatási anyagok',icon:'▰',description:'A meglévő szakági oktatási mappák.'},
  {route:'elearning',label:'E-learning',icon:'▶',description:'Interaktív képzések és tananyagok.'},
  {route:'knowledge-background',label:'Háttéranyagok',icon:'▣',description:'Közös munkaanyagok Google Drive-ban.'},
  {route:'knowledge-links',label:'Hasznos linkek',icon:'↗',description:'Weboldalak gyors elérése névvel és leírással.'},
  {route:'knowledge-pdfs',label:'PDF-dokumentumok',icon:'▤',description:'Feltöltött PDF-ek megnyitása.'},
  {route:'knowledge-lectures',label:'Előadások',icon:'▣',description:'A korábban feltöltött előadások és új anyagok.'}
 ].sort((a,b)=>collator.compare(a.label,b.label)).map(Object.freeze));
 function url(value){let u;try{u=new URL(String(value).trim());}catch{throw Error('Teljes, https:// kezdetű webcímet adj meg.');}if(!['https:','http:'].includes(u.protocol)||u.username||u.password)throw Error('Csak hitelesítő adat nélküli http vagy https webcím menthető.');return u.href;}
 function text(value,max,required=false){const s=String(value||'').trim();if(required&&!s)throw Error('Adj meg egy címet.');if(s.length>max)throw Error('Túl hosszú szöveg.');return s;}
 function link(values){return {title:text(values.title,200,true),description:text(values.description,2000),url:url(values.url)};}
 async function pdf(file){if(!file||!String(file.name).toLowerCase().endsWith('.pdf')||file.type&&file.type!=='application/pdf')throw Error('PDF-fájlt válassz.');if(file.size<5||file.size>50*1024*1024)throw Error('A PDF mérete legfeljebb 50 MB lehet.');const head=new Uint8Array(await file.slice(0,5).arrayBuffer());if(String.fromCharCode(...head)!=='%PDF-')throw Error('A fájl nem felismerhető PDF.');return file;}
 const fold=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('hu-HU');
 const isVisibleMaterial=row=>Boolean(row&&row.visibility==='members'&&(!row.newsroom_item_id||row.newsroom_state==='published'));
 function filter(rows,query){const words=fold(query).split(/\s+/).filter(Boolean);return rows.filter(r=>words.every(w=>fold([r.title,r.description,r.file_name].join(' ')).includes(w)));}
 return Object.freeze({categories,routes,menu,url,text,link,pdf,filter,isVisibleMaterial});
});
