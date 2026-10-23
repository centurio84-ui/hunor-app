// Read-only audit of the actual CI lockfile against the official pub.dev metadata/advisories.
import fs from 'node:fs/promises';
const [lockPath,outPath]=process.argv.slice(2);if(!lockPath||!outPath)throw Error('Usage: LOCKFILE REPORT.json');
const lock=(await fs.readFile(lockPath,'utf8')).replaceAll('\r\n','\n');
const packages=lock.split(/\n(?=  [a-zA-Z0-9_]+:\n)/).flatMap(block=>{
 const name=/^  ([a-zA-Z0-9_]+):\n/.exec(block)?.[1];if(!name||!/^    source: hosted$/m.test(block))return [];
 const version=/^    version: "([^"]+)"/m.exec(block)?.[1],sha=/^      sha256: "?([a-f0-9]{64})"?/m.exec(block)?.[1],url=/^      url: "([^"]+)"/m.exec(block)?.[1];
 if(!version||!sha||url!=='https://pub.dev')throw Error('Unexpected hosted dependency: '+name);
 return [{name,version,sha}];
});
if(!packages.length)throw Error('No locked hosted packages');
let next=0;const results=[];
async function get(url){const r=await fetch(url,{signal:AbortSignal.timeout(30000)});if(!r.ok)throw Error('Official metadata HTTP '+r.status);return r.json();}
await Promise.all(Array.from({length:5},async()=>{while(next<packages.length){const p=packages[next++];try{
 const [v,a]=await Promise.all([get(`https://pub.dev/api/packages/${p.name}/versions/${encodeURIComponent(p.version)}`),get(`https://pub.dev/api/packages/${p.name}/advisories`)]);
 const matches=v.archive_sha256===p.sha;
 const advisories=(a.advisories||[]).filter(x=>!x.withdrawn&&(x.affected||[]).some(y=>y.package?.name===p.name&&(y.versions||[]).includes(p.version))).map(x=>({id:x.id,summary:x.summary,url:x.database_specific?.pub_display_url}));
 results.push({name:p.name,version:p.version,archiveHashMatches:matches,advisories});
 }catch(e){results.push({name:p.name,version:p.version,error:e.message});}}}));
const report={at:new Date().toISOString(),scope:'Hosted Dart packages from supplied actual CI lockfile; not APK malware scanning or native Maven audit',checked:results.length,hashMismatch:results.filter(x=>x.archiveHashMatches===false),errors:results.filter(x=>x.error),affected:results.filter(x=>x.advisories?.length),packages:results.sort((a,b)=>a.name.localeCompare(b.name))};
await fs.writeFile(outPath,JSON.stringify(report,null,2));console.log(JSON.stringify({checked:report.checked,hashMismatch:report.hashMismatch,errors:report.errors,affected:report.affected}));
if(report.hashMismatch.length||report.errors.length||report.affected.length)process.exitCode=1;
