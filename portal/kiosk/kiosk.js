/* Existing quiz engine: local practice by default, explicit optional server play. */
window.HunorKiosk = (() => {
  'use strict';
  const modes = {
    children: {icon:'flashlight', title:'Iskolás & Gyerek Mód', count:5, seconds:25},
    public: {icon:'shield', title:'Lakossági Biztonság', count:8, seconds:20},
    pro: {icon:'trophy', title:'HUNOR Pro Kihívás', count:10, seconds:15}
  };
  const topics={all:'Vegyes kérdések',basics:'Általános felkészültség',weather:'Extrém időjárás',survival:'Túlélési alapismeretek',myths:'Katasztrófavédelmi mítoszok',hunor:'HUNOR és USAR',festival:'Fesztivál- és tömegrendezvény-biztonság',cyber:'Digitális biztonság és adathalászat',traffic:'Gépjárműbaleset'};
  const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const shuffle = items => {const a=[...items];for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;};
  let root, bank=[], mode='children', state='start', name='', questions=[], index=0, score=0, answered=false;
  let remote=null,remoteContext=null,unsubscribe=null,online=false,sessionId=null,finishAck=null,epoch=0,contextRevision=0;
  let shareURL=null;
  const releaseImage=()=>{if(shareURL)URL.revokeObjectURL(shareURL);shareURL=null;};
  let readingPause=false;
  let interval, deadline=0, lastActivity=0, abort;
  const frame = body => `<section class="hk"><header class="hk-brand"><span class="hk-mark" aria-hidden="true">H</span><span>HUNOR <small>KUTATÁS · MENTÉS · TÁMOGATÁS</small></span><span class="hk-kiosk-label">TUDÁS, AMI SEGÍTHET</span></header><main class="hk-card">${body}</main><footer class="hk-footer">Ismeretterjesztő játék · Valódi veszélyhelyzetben: <strong>112</strong><span id="hkIdle" role="status"></span></footer></section>`;
  const guide = (kind, n=0) => '<aside class="mc-guide" aria-label="MAD Chief kvízvezető"><img src="/kiosk/assets/mad-chief.webp" alt="MAD Chief narancssárga mentősisakban" width="110" height="130"><div class="mc-bubble"><strong>MAD Chief</strong><p>'+escape(MadChief.speech(kind,n))+'</p></div></aside>';
  function render(body) {releaseImage();root.innerHTML=frame(body);root.querySelector('h1,h2')?.focus({preventScroll:true});}
  async function rank(cohort='mixed',page=0) {
    if(!HunorQuizRank.cohorts[cohort])cohort='mixed';page=Math.max(0,Math.min(1000,Number.isInteger(page)?page:0));
    state='rank';name='';questions=[];deadline=0;lastActivity=performance.now();
    render(`<div class="hk-eyebrow">VESZÉLYHELYZETI KVÍZ</div><h2 tabindex="-1">Online ranglista</h2><p class="hk-intro">Közzétett, szerveren mentett eredmények. Az eltérő hosszúságú játékmódok külön listán szerepelnek.</p><label class="hk-name">Ranglista kiválasztása<select id="hkRankCohort" class="hq-input">${Object.entries(HunorQuizRank.cohorts).map(([id,c])=>`<option value="${id}" ${id===cohort?'selected':''}>${escape(c.title)}</option>`).join('')}</select></label><details class="hk-note"><summary>Miért nem minden látogató szerepel itt?</summary><p>A látogatásszámláló oldalmegnyitásokat számol, nem befejezett kvízeket. A korábbi kioszk nem küldte el a körök eredményét. A listához szerveres eredménymentés és külön nyilvános ranglistaválasztás szükséges. Azonos pontszám holtversenyt jelent, ezért például 1., 1., 3. helyezések is szerepelhetnek.</p></details><div id="hkRank" role="status">Eredmények betöltése…</div><button class="hk-primary" id="hkRankBack">Vissza a játékhoz →</button>`);
    root.querySelector('#hkRankBack').onclick=reset;root.querySelector('#hkRankCohort').onchange=e=>rank(e.target.value);
    const target=root.querySelector('#hkRank');
    try {
      const query=new URLSearchParams({mode:cohort,period:'all',limit:'10',page:String(page)});
      const response=await fetch('/api/public-quiz/leaderboard?'+query,{credentials:'omit',cache:'no-store',signal:abort.signal});
      if(!response.ok)throw Error('A ranglista most nem érhető el.');const data=await response.json();if(!target.isConnected||state!=='rank')return;
      if(!data.enabled){target.textContent='A ranglista közzététele jelenleg nem aktív.';return;}
      const rows=HunorQuizRank.validate(data.rows,cohort);if(!rows.length){target.textContent='Ebben a játékmódban még nincs közzétett, szerveren mentett eredmény.';return;}
      target.removeAttribute('role');target.innerHTML=`<p class="hk-note">${escape(data.total)} közzétett játékosprofil ebben a módban · ${page+1}. oldal</p><div class="hq-rank-wrap"><table class="hq-table"><caption class="hk-note">${escape(HunorQuizRank.cohorts[cohort].title)}</caption><thead><tr><th scope="col">Hely</th><th scope="col">Becenév</th><th scope="col">Helyes válaszok</th><th scope="col">Pontszám</th></tr></thead><tbody>${rows.map(r=>`<tr><td>${escape(r.rank)}.</td><th scope="row">${escape(r.display_name)} <small class="hq-muted">${escape(r.short_code||'')}</small></th><td>${r.correct} / ${r.total} · ${escape(r.percent)}%</td><td class="hq-rank-score">${r.lrc} LRC</td></tr>`).join('')}</tbody></table></div>${page>0?'<button class="hk-text" id="hkRankPrevious">Előző oldal</button>':''}${Number(data.total)>(page+1)*10?'<button class="hk-text" id="hkRankNext">Következő oldal</button>':''}`;
      if(root.querySelector('#hkRankPrevious'))root.querySelector('#hkRankPrevious').onclick=()=>rank(cohort,page-1);
      if(root.querySelector('#hkRankNext'))root.querySelector('#hkRankNext').onclick=()=>rank(cohort,page+1);
    }catch(error){if(target.isConnected&&state==='rank')target.textContent=error.message||'A ranglista most nem érhető el.';}
  }
  function reset() {
    epoch++;online=false;sessionId=null;finishAck=null;readingPause=false;state='start';name='';questions=[];index=score=0;answered=false;deadline=0;mode='children';lastActivity=performance.now();
    render(`<div class="hq-hero"><div class="hk-eyebrow">KÉSZEN ÁLLSZ?</div><h1 tabindex="-1"><strong>Veszélyhelyzeti Kvíz</strong></h1><p>Néhány perc játék. Tudás, amit magaddal vihetsz.</p></div>${guide('welcome')}<ul class="hq-checklist"><li>${HunorQuizUI.icon("check")} Rövid, pörgős kihívások</li><li>${HunorQuizUI.icon("check")} Azonnali magyarázatok</li><li>${HunorQuizUI.icon("check")} Regisztráció nélkül</li></ul><form id="hkStart"><label class="hk-name">Becenév / csapatnév <span>nem kötelező</span><input name="nickname" maxlength="30" autocomplete="off" placeholder="Például: Villámcsapat"></label><label class="hk-name">Kérdések témája<select name="topic" class="hq-input">${Object.entries(topics).filter(([id])=>id==="all"||bank.some(q=>q.topic===id)).map(([id,label])=>`<option value="${id}">${label}</option>`).join("")}</select></label><fieldset class="hk-modes"><legend>Válaszd ki a kihívásodat</legend>${Object.entries(modes).map(([id,m])=>`<label class="hk-mode"><input type="radio" name="mode" value="${id}" ${id===mode?'checked':''}><span class="hk-mode-content"><span class="hk-mode-icon" aria-hidden="true">${HunorQuizUI.icon(m.icon)}</span><b>${m.title}</b><small>${m.count} gyors kérdés · ${m.seconds} mp / kérdés</small><span class="hk-selected" aria-hidden="true">✓</span></span></label>`).join('')}</fieldset><button class="hk-primary hk-launch" type="submit">KVÍZ INDÍTÁSA <span aria-hidden="true">→</span></button><p class="hk-note">Online választás nélkül a becenév és a pontszám csak ezen a képernyőn, a játék végéig él.</p><button type="button" class="hk-text" id="hkRankOpen">${HunorQuizUI.icon("trophy")} Online ranglista</button></form>`);
    root.querySelector("#hkRankOpen").onclick=()=>rank();attachOnlineOptions();
    root.querySelector('#hkStart').onsubmit=async e=>{
      e.preventDefault();const f=new FormData(e.currentTarget);mode=f.get('mode');if(!modes[mode])return;const topic=f.get('topic');
      if((f.get('public_rank')||f.get('save_result'))&&!f.get('online')){root.querySelector('#hkOnlineNotice').textContent='A mentéshez vagy ranglistához válaszd az online pontozást és ismerd meg a tájékoztatót.';return;}
      name=String(f.get('nickname')||'').trim()||`Látogató-#${crypto.getRandomValues(new Uint32Array(1))[0]%9000+1000}`;score=index=0;
      if(f.get('online')&&remoteContext?.enabled){
        online=true;const current=epoch;remoteLoading('Online kör indítása…');
        try{const data=await remote.request('start',{client_mode:mode,topic,mode:'mixed',display_name:name,game_consent:true,notice_version:Number(remoteContext.noticeVersion),save_result:!!f.get('save_result'),result_retention_consent:!!f.get('save_result'),leaderboard_consent:!!f.get('public_rank'),research_consent:false});
          if(current!==epoch)return;if(typeof data.session_id!=='string'||data.total!==modes[mode].count)throw Error('A szerver nem a kiválasztott kört igazolta.');
          sessionId=data.session_id;questions=Array.from({length:data.total},()=>({}));await question();
        }catch(error){if(current===epoch)remoteError(error.message);}return;
      }
      const pool=bank.filter(q=>q.modes.includes(mode)&&(topic==='all'||q.topic===topic));if(pool.length<modes[mode].count)return showError();
      questions=shuffle(pool).slice(0,modes[mode].count).map(q=>({...q,choices:shuffle(q.choices.map((text,i)=>({text,correct:i===q.correctIndex})))}));state='question';lastActivity=performance.now();question();
    };
  }
  async function question() {
    if(index>=questions.length)return result();
    if(online){const current=epoch;remoteLoading('Kérdés betöltése…');try{
      const data=await remote.request('next',{session_id:sessionId});if(current!==epoch)return;
      if(data.complete||data.seq!==index+1||data.total!==questions.length||typeof data.question!=='string'||!Array.isArray(data.choices)||data.choices.length<2||data.choices.length>4||data.choices.some(c=>typeof c!=='string'))throw Error('A kérdés nem egyezik az elindított körrel.');
      questions[index]={question:data.question,category:data.category,choices:data.choices.map(text=>({text,correct:false}))};
    }catch(error){if(current===epoch)remoteError(error.message,question);return;}}
    state='question';answered=false;lastActivity=performance.now();deadline=lastActivity+modes[mode].seconds*1000;
    const q=questions[index];
    render(`${guide('question',index)}<div class="hk-question-top"><span>${escape(modes[mode].title)}</span><strong>${index+1} / ${questions.length}</strong><span class="mc-live-score" id="mcScore">${score} pont</span><span class="hk-clock" role="timer" aria-label="Hátralévő kérdésidő"><b id="hkTime">${modes[mode].seconds}</b> mp</span></div><progress max="${questions.length}" value="${index}" aria-label="Haladás"></progress><div class="hk-topic-tag">${escape(q.category||topics[q.topic]||"Általános felkészültség")}${q.choices.length===2?" · Igaz / Hamis":""}</div><h2 tabindex="-1">${escape(q.question)}</h2><div class="hk-answers">${q.choices.map((c,i)=>`<button type="button" class="hk-answer" data-answer="${i}"><span>${String.fromCharCode(65+i)}</span>${escape(c.text)}</button>`).join('')}</div><div id="hkFeedback" aria-live="polite"></div><button type="button" class="hk-text" id="hkExit">Új játék / kezdőképernyő</button>`);
    root.querySelectorAll('[data-answer]').forEach(b=>b.onclick=()=>{if(performance.now()>=deadline)answer(null);else answer(Number(b.dataset.answer));});
    root.querySelector('#hkExit').onclick=reset;
  }
  async function answer(choice) {
    if(answered||state!=='question')return;answered=true;deadline=0;
    const q=questions[index];let correct=choice!==null&&q.choices[choice].correct;
    if(online){state='checking';const current=epoch;root.querySelectorAll('[data-answer]').forEach(b=>b.disabled=true);root.querySelector('#hkFeedback').textContent='Válasz szerveres ellenőrzése…';try{
      const data=await remote.request('answer',{session_id:sessionId,seq:index+1,choice:choice===null?-1:choice});if(current!==epoch)return;
      if(typeof data.correct!=='boolean'||!Number.isInteger(data.correct_index)||data.correct_index<0||data.correct_index>=q.choices.length)throw Error('A szerver válasza nem ellenőrizhető.');
      correct=data.correct;if(Number.isInteger(data.choice))choice=data.choice<0?null:data.choice;
      q.choices.forEach((c,i)=>c.correct=i===data.correct_index);q.explanation=data.explanation;q.source=data.source_url;q.didYouKnow=data.didYouKnow;
    }catch(error){if(current!==epoch)return;state='question';answered=false;root.querySelector('#hkFeedback').innerHTML='<p role="alert">'+escape(error.message)+'</p><button class="hk-primary" id="hkRetryAnswer">Válasz ellenőrzésének újrapróbálása</button>';root.querySelector('#hkRetryAnswer').onclick=()=>answer(choice);return;}}

    state='feedback';lastActivity=performance.now();
    if(correct)score+=10;
    root.querySelectorAll('[data-answer]').forEach(b=>{const i=Number(b.dataset.answer);b.disabled=true;if(q.choices[i].correct)b.classList.add('hk-correct');else if(i===choice)b.classList.add('hk-wrong');});
    root.querySelector('.mc-bubble p').textContent=MadChief.speech(choice===null?'timeout':correct?'correct':'wrong',index);
    root.querySelector('#mcScore').textContent=score+' pont';const clock=root.querySelector('.hk-clock');clock.textContent='Megválaszolva';clock.removeAttribute('role');clock.setAttribute('aria-label','Kérdés megválaszolva');
    root.querySelector('progress').value=index+1;
    const learning=MadChief.education(q);
    root.querySelector('#hkFeedback').innerHTML=`<section class="hk-feedback ${correct?'hk-feedback-good':''}"><h3>${choice===null?'Lejárt a kérdésidő':correct?'✓ Helyes válasz! +10 pont':'Ebből is tanulhatsz!'}</h3><p><strong>Helyes válasz:</strong> ${escape(q.choices.find(c=>c.correct).text)}</p>${learning?`<aside class="mc-learning" aria-label="Oktatókártya"><h3>◉ ${escape(learning.title)}</h3><p>${escape(learning.text)}</p>${learning.image?`<img src="${escape(learning.image)}" alt="${escape(learning.imageAlt)}">`:""}</aside>`:""}${/^https:\/\//.test(q.source)?`<details><summary>Szakmai forrás</summary><span class="hk-source">${escape(q.source)}</span></details>`:''}<button type="button" class="hk-text" id="mcReadingPause" aria-pressed="false">Több idő az olvasáshoz</button><button type="button" class="hk-primary" id="hkNext">${index===questions.length-1?'Eredményem':'Következő kérdés'} →</button></section>`;
    root.querySelector('#mcReadingPause').onclick=e=>{readingPause=!readingPause;e.currentTarget.setAttribute('aria-pressed',String(readingPause));e.currentTarget.textContent=readingPause?'Olvasási szünet bekapcsolva':'Több idő az olvasáshoz';};root.querySelector('#hkNext').onclick=()=>{readingPause=false;index++;question();};root.querySelector('#hkNext').focus({preventScroll:true});
  }
  async function result(){if(online&&!finishAck){const current=epoch;remoteLoading('Eredmény mentésének ellenőrzése…');try{
    const data=await remote.request('finish',{session_id:sessionId});if(current!==epoch)return;
    if(data.session_id!==sessionId||data.total!==questions.length||!Number.isInteger(data.correct)||data.correct<0||data.correct>data.total||data.lrc!==data.correct*10)throw Error('A szerver nem igazolta az eredményt.');score=data.lrc;finishAck=data;
  }catch(error){if(current===epoch)remoteError(error.message,result);return;}}showResult();}
  function showResult() {const badge=MadChief.grade(score/10,questions.length);state='result';deadline=0;lastActivity=performance.now();render(`${guide('finish')}<div class="mc-badge" aria-hidden="true">${badge.symbol}</div><div class="hk-eyebrow">SZÉP MUNKA, ${escape(name)}!</div><h2 tabindex="-1">${escape(badge.title)}</h2><div class="hk-score">${score}<small> / ${questions.length*10} pont</small></div><p>${score/10} helyes válasz a ${questions.length} kérdésből · ${Math.round(score/(questions.length*10)*100)}%</p><p class="hk-intro">A legfontosabb nyeremény: a tudásod.</p><section class="mc-sharing" aria-label="Eredmény megosztása"><label><input type="checkbox" id="mcIncludeName"> A becenevem is szerepeljen a megosztott képen</label><a class="hk-primary" id="mcDownload" download="veszelyhelyzeti-kviz-eredmeny.png" aria-disabled="true" tabindex="-1">Eredménykártya mentése</a><button type="button" class="hk-text" id="mcShare">Kép megosztása</button><span id="mcShareStatus" role="status"></span><img id="mcResultPreview" hidden alt="A megosztható eredménykártya előnézete" width="1200" height="630"></section><button type="button" id="hkReplay" class="hk-primary hk-launch">Következő játékos →</button><p class="hk-note">${online?"A szerver visszaigazolta a kör lezárását. "+(finishAck.leaderboard_consent?"Az eredmény ranglistára engedélyezett.":"Ez az eredmény nem nyilvános."):"15 másodperc tétlenség után új játék indul. A helyi gyakorlás pontjai nem kerülnek a ranglistára."}</p>`);root.querySelector('#hkReplay').onclick=reset;
    const resultRoot=root, resultQuestions=questions;let image=null;
    const prepare=async()=>{image=null;releaseImage();const link=resultRoot.querySelector('#mcDownload');link.removeAttribute('href');link.setAttribute('aria-disabled','true');link.tabIndex=-1;resultRoot.querySelector('#mcResultPreview').hidden=true;const includeName=resultRoot.querySelector('#mcIncludeName').checked;resultRoot.querySelectorAll('#mcDownload,#mcShare').forEach(b=>b.disabled=true);const data=MadChief.shareData({correct:score/10,total:questions.length,score,name,includeName});try{const blob=await MadChiefShare.create(data);if(root===resultRoot && state==='result' && questions===resultQuestions && resultRoot.querySelector('#mcIncludeName')?.checked===includeName){image=blob;shareURL=URL.createObjectURL(blob);link.href=shareURL;link.setAttribute('aria-disabled','false');link.tabIndex=0;const preview=resultRoot.querySelector('#mcResultPreview');preview.src=shareURL;preview.hidden=false;resultRoot.querySelectorAll('#mcDownload,#mcShare').forEach(b=>b.disabled=false);}}catch(e){if(state==='result')resultRoot.querySelector('#mcShareStatus').textContent=e.message;}};
    resultRoot.querySelector('#mcIncludeName').onchange=prepare;prepare();
    resultRoot.querySelector('#mcShare').onclick=async()=>{if(!image)return;const file=new File([image],'veszelyhelyzeti-kviz-eredmeny.png',{type:'image/png'});if(!navigator.canShare?.({files:[file]})){resultRoot.querySelector('#mcShareStatus').textContent='Mentsd le a képet, majd oszd meg a választott alkalmazásban.';return;}try{await navigator.share({files:[file],title:'Veszélyhelyzeti Kvíz'});}catch(e){if(e.name!=='AbortError' && state==='result')resultRoot.querySelector('#mcShareStatus').textContent='A megosztás nem sikerült. A kép lementhető.';}};
  }
  function tick() {
    if(!root?.isConnected)return destroy();
    const now=performance.now(),idle=now-lastActivity;
    const canIdleReset=!readingPause&&!['question','loading','checking'].includes(state);
    if(canIdleReset&&idle>=15000){if(state!=='start'||root.querySelector('input[name="nickname"]')?.value||mode!=='children'||root.querySelector('[name="topic"]')?.value!=='all'||!root.querySelector('input[value="children"]')?.checked)reset();else lastActivity=now;return;}
    const notice=root.querySelector('#hkIdle');if(notice)notice.textContent=readingPause?'Olvasási szünet — a folytatáshoz válaszd a következő kérdést.':canIdleReset&&idle>=10000&&state!=='start'?`Új játék ${Math.ceil((15000-idle)/1000)} mp múlva — érintsd meg a képernyőt a folytatáshoz.`:'';
    if(state==='question'&&!answered&&deadline>0){const left=Math.max(0,Math.ceil((deadline-now)/1000));const timer=root.querySelector('#hkTime');if(timer)timer.textContent=left;root.querySelector('.hk-clock')?.classList.toggle('hk-clock-urgent',left<=5);if(now>=deadline)answer(null);}
  }
  function attachOnlineOptions(){const form=root?.querySelector('#hkStart');if(!form||!remoteContext?.enabled||form.querySelector('#hkOnlineOptions'))return;
    const html=`<fieldset class="mc-online-options" id="hkOnlineOptions"><legend>Online eredmény és ranglista</legend><label><input type="checkbox" name="online"> Kérem az online pontozást; megismertem az alábbi adatkezelési tájékoztatót.</label><label><input type="checkbox" name="public_rank"> A becenevem és eredményem szerepeljen a nyilvános ranglistán.</label>${remoteContext.loggedIn?'<label><input type="checkbox" name="save_result"> Kérem az eredmény és jelvény megőrzését a saját fiókomban.</label><button type="button" class="hk-text" id="hkHistoryOpen">Korábbi saját eredményeim</button>':''}<details><summary>Adatkezelés és megőrzés</summary><p>${escape(remoteContext.privacyText)}</p><p>Adatkezelő: ${escape(remoteContext.controllerName||'A portál adatkezelője')}. Az online kör 1 napig, ranglistás vagy fiókhoz mentett eredmény ${escape(remoteContext.retentionDays)} napig marad meg. Kutatási részvétel nem kapcsolódik be.</p></details><p role="alert" id="hkOnlineNotice"></p><p>Választás nélkül helyi gyakorlókör indul, szerveres eredmény és ranglista nélkül.</p></fieldset>`;
    form.querySelector('button[type="submit"]').insertAdjacentHTML('beforebegin',html);if(root.querySelector('#hkHistoryOpen'))root.querySelector('#hkHistoryOpen').onclick=history;
  }
  async function refreshRemote(signal){const revision=++contextRevision;try{const context=await remote.context();if(signal.aborted||!root||revision!==contextRevision)return;
    if(context?.enabled&&Number.isInteger(Number(context.noticeVersion))&&Number(context.retentionDays)>=1&&Number(context.retentionDays)<=365&&typeof context.privacyText==='string'){remoteContext=context;attachOnlineOptions();}
  }catch{/* Local practice stays available. */}}
  function remoteLoading(text){state='loading';deadline=0;render('<h2 tabindex="-1">'+escape(text)+'</h2><p role="status">A szerver válaszára várunk.</p><button class="hk-text" id="hkCancel">Vissza a kezdőképernyőre</button>');root.querySelector('#hkCancel').onclick=reset;}
  function remoteError(message,retry){state='error';deadline=0;render('<h2 tabindex="-1">A művelet nem igazolt</h2><p role="alert">'+escape(message)+'</p>'+(retry?'<button class="hk-primary" id="hkRemoteRetry">Újrapróbálás</button>':'')+'<button class="hk-text" id="hkCancel">Vissza a kezdőképernyőre</button>');if(retry)root.querySelector('#hkRemoteRetry').onclick=retry;root.querySelector('#hkCancel').onclick=reset;}
  async function history(){const current=epoch;remoteLoading('Saját eredmények betöltése…');try{const data=await remote.request('my_results');if(current!==epoch)return;if(!Array.isArray(data.rows))throw Error('Az eredménylista nem olvasható.');state='history';render('<h2 tabindex="-1">Korábbi saját eredményeim</h2>'+data.rows.map(row=>'<article class="mc-learning"><h3>'+escape(row.rating?.title||'Saját eredmény')+'</h3><p>'+escape(row.correct_count)+' / '+escape(row.question_total)+' helyes válasz · '+escape(row.rating?.percent)+'%</p><p>'+escape(row.finished_at)+'</p></article>').join('')+(data.rows.length?'':'<p>Még nincs megőrzött eredményed.</p>')+'<button class="hk-primary" id="hkCancel">Vissza a játékhoz</button>');root.querySelector('#hkCancel').onclick=reset;}catch(error){if(current===epoch)remoteError(error.message,history);}}
  function showError(){render('<h1 tabindex="-1">A kérdések most nem tölthetők be</h1><p>Ellenőrizd a kapcsolatot, majd próbáld újra.</p><button class="hk-primary" id="hkRetry">Újrapróbálás</button>');root.querySelector('#hkRetry').onclick=()=>mount(root);}
  function destroy(){epoch++;unsubscribe?.();unsubscribe=null;remote=null;remoteContext=null;online=false;sessionId=null;finishAck=null;releaseImage();clearInterval(interval);abort?.abort();document.body.classList.remove('hunor-kiosk');root=null;bank=[];name='';questions=[];state='start';}
  async function mount(element,options={}) {
    destroy();root=element;document.body.classList.add('hunor-kiosk');abort=new AbortController();const signal=abort.signal;render('<h1 tabindex="-1">Veszélyhelyzeti Kvíz</h1><p role="status">Kérdések betöltése…</p>');
    try {const response=await fetch('/kiosk/questions.json',{signal,cache:'no-cache',credentials:'same-origin'});if(!response.ok)throw Error('bank');const data=await response.json();if(signal.aborted)return;if(!Array.isArray(data)||!data.every(q=>typeof q.question==='string'&&Array.isArray(q.choices)&&q.choices.length>=2&&q.choices.length<=4&&q.choices.every(c=>typeof c==="string")&&Number.isInteger(q.correctIndex)&&q.correctIndex>=0&&q.correctIndex<q.choices.length&&Array.isArray(q.modes)))throw Error('bank');bank=data;
      for(const type of ['pointerdown','keydown','input','change','wheel'])root.addEventListener(type,()=>{lastActivity=performance.now();},{signal,passive:true});
      document.addEventListener('visibilitychange',tick,{signal});window.addEventListener('pagehide',destroy,{signal});reset();interval=setInterval(tick,200);
      try{remote=options.remote||(parent!==window?parent.HunorQuizMemberService:null)||window.HunorQuizRemoteService?.create();if(remote){unsubscribe=remote.subscribe?.(()=>{remoteContext=null;reset();refreshRemote(signal);});refreshRemote(signal);}}catch{remote=null;}
    } catch(e){if(!signal.aborted&&root)showError();}
  }
  return {mount,destroy};
})();
