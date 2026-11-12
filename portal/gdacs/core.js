// Same implementation is loaded as a classic browser script and by Node tests.
(function(root){
 'use strict';
 const types=Object.freeze({EQ:'Földrengés',TC:'Trópusi ciklon',FL:'Árvíz',VO:'Vulkán',DR:'Aszály',WF:'Erdőtűz'});
 function normalize(data,type){
  if(data?.type!=='FeatureCollection'||!Array.isArray(data.features))throw Error('Érvénytelen GDACS-adat.');
  const seen=new Set(),rows=[];
  for(const f of data.features){const p=f.properties||{},c=f.geometry?.coordinates;
   if(f.geometry?.type!=='Point'||!Array.isArray(c)||c.length!==2||!c.every(Number.isFinite)||Math.abs(c[0])>180||Math.abs(c[1])>90||p.eventtype!==type||!Number.isSafeInteger(Number(p.eventid))||Number(p.eventid)<=0)continue;
   const id=type+'-'+p.eventid;if(seen.has(id))continue;seen.add(id);
   const raw=p.datemodified||p.todate,stamp=typeof raw==='string'?Date.parse(raw.endsWith('Z')||/[+-]\d\d:\d\d$/.test(raw)?raw:raw+'Z'):NaN;
   rows.push({id,type,lat:c[1],lon:c[0],level:['Green','Orange','Red'].includes(p.alertlevel)?p.alertlevel:'Unknown',title:String(p.name||p.description||types[type]).slice(0,400),country:String(p.country||'').slice(0,160),updated:Number.isFinite(stamp)?stamp:null,url:'https://www.gdacs.org/report.aspx?'+new URLSearchParams({eventtype:type,eventid:String(p.eventid)})});
  }return rows;
 }
 const api=Object.freeze({types,normalize});if(typeof module==='object')module.exports=api;else root.HunorGdacsCore=api;
})(globalThis);
