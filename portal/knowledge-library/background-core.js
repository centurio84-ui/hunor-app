(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.HunorBackgroundCore=api;})(typeof window==='object'?window:globalThis,()=>{
 'use strict';
 // Presentation rules only. The backend must enforce the same rules independently.
 const manager=a=>Boolean(a?.approved&&!a.guest&&(a.admin||a.membershipManager));
 const canRead=(a,row)=>Boolean(a?.approved&&!a.guest&&(manager(a)||row?.visibility==='members'));
 function driveFolder(value){const u=new URL(value);if(u.protocol!=='https:'||u.hostname!=='drive.google.com'||u.username||u.password||u.search||u.hash)throw Error('Google Drive-mappa hivatkozás szükséges.');const m=u.pathname.match(/^\/drive\/(?:u\/\d+\/)?folders\/([A-Za-z0-9_-]+)\/?$/);if(!m)throw Error('Google Drive-mappa hivatkozás szükséges.');return 'https://drive.google.com/drive/folders/'+m[1];}
 function folder(input){const title=String(input.title||'').trim();if(!title||title.length>200)throw Error('Adj meg legfeljebb 200 karakteres mappanevet.');return {title,url:driveFolder(input.url),visibility:'managers'};}
 function publish(a,id,visible){if(!a?.approved||a.guest||!a.admin)throw Error('Csak admin módosíthatja a tagi láthatóságot.');if(!id||typeof visible!=='boolean')throw Error('Érvénytelen módosítás.');return {id,visibility:visible?'members':'managers'};}
 return Object.freeze({manager,canRead,driveFolder,folder,publish});
});
