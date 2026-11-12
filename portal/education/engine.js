(function(root,factory){const api=factory();if(typeof module==='object')module.exports=api;else root.HunorLearning=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
 'use strict';
 const types=['single','multiple','boolean','case'];
 const id=/^[a-z0-9][a-z0-9-]{0,63}$/;
 function validate(c){
  if(!c||!id.test(c.id)||!Number.isInteger(c.version)||c.version<1||c.status!=='sample')throw Error('Csak verziózott mintakurzus importálható.');
  if(typeof c.title!=='string'||!c.title.trim()||!Array.isArray(c.modules)||!c.modules.length||c.modules.length>30)throw Error('Hibás kurzus.');
  const ids=new Set(),lessons=[];
  const unique=x=>{if(!id.test(x)||ids.has(x))throw Error('Hibás vagy ismételt azonosító.');ids.add(x);};unique(c.id);
  const text=x=>{if(typeof x!=='string'||x.length>30000)throw Error('Hibás szöveg.');};
  function question(q){unique(q.id);if(!types.includes(q.type))throw Error('Ismeretlen kérdéstípus.');text(q.prompt);text(q.explanation);if(!Array.isArray(q.answers)||q.answers.length<2||q.answers.length>8)throw Error('Hibás válaszlista.');const a=new Set();q.answers.forEach(v=>{if(!id.test(v.id)||a.has(v.id)||typeof v.correct!=='boolean')throw Error('Hibás válasz.');a.add(v.id);text(v.text);});const n=q.answers.filter(a=>a.correct).length;if(!n||(q.type!=='multiple'&&n!==1)||(q.type==='boolean'&&q.answers.length!==2))throw Error('Hibás megoldókulcs.');}
  c.modules.forEach(m=>{unique(m.id);text(m.title);if(!Array.isArray(m.lessons)||!m.lessons.length||m.lessons.length>40)throw Error('Hibás fejezet.');m.lessons.forEach(l=>{unique(l.id);text(l.title);if(!Array.isArray(l.blocks)||!l.blocks.length||l.blocks.length>40)throw Error('Hibás lecke.');l.blocks.forEach(b=>{if(b.type==='text'||b.type==='callout')text(b.text);else if(b.type==='image'){text(b.alt);const u=new URL(b.src,'https://example.invalid');if(u.protocol!=='https:'||(!b.src.startsWith('/education/')&&u.hostname!=='images.unsplash.com'))throw Error('Tiltott képforrás.');}else if(b.type==='video'){const u=new URL(b.src);if(u.protocol!=='https:'||!['www.youtube-nocookie.com','player.vimeo.com'].includes(u.hostname)||!/^\/(embed\/|video\/)\d*[a-zA-Z0-9_-]+$/.test(u.pathname))throw Error('Tiltott videóforrás.');text(b.title);}else if(b.type==='question'||b.type==='case')question(b.question);else throw Error('Ismeretlen tartalomblokk.');});lessons.push(l);});});
  if(c.characterWorld){
   if(c.characterWorld!=='matyi-andras')throw Error('Ismeretlen karaktervilág.');
   for(const l of lessons){const images=l.blocks.filter(b=>b.type==='image'&&b.illustration);if(!images.length)throw Error('Minden leckéhez karakterillusztráció vagy helyőrző szükséges.');
    for(const b of images){const i=b.illustration;if(i.world!==c.characterWorld||!Array.isArray(i.characters)||i.characters.length!==2||!['matyi','andras'].every(x=>i.characters.includes(x))||!['placeholder','demonstration','approved'].includes(i.status)||typeof i.medical!=='boolean'||!['not-applicable','pending','approved'].includes(i.professionalApproval)||typeof i.topic!=='string'||!i.topic.trim()||!/^\/education\/illustrations\/[a-z0-9-]+\.(svg|webp|png|jpg)$/.test(b.src))throw Error('Hibás karakterillusztráció.');
     if(i.medical&&(i.professionalApproval==='not-applicable'||i.status==='approved'&&i.professionalApproval!=='approved'))throw Error('Egészségügyi ábra csak szakmai jóváhagyással véglegesíthető.');
    }
   }
  }
  if(!c.quiz||!Number.isInteger(c.quiz.questionCount)||c.quiz.questionCount<1||c.quiz.questionCount>100||!Number.isFinite(c.quiz.passPercent)||c.quiz.passPercent<1||c.quiz.passPercent>100||!Array.isArray(c.quiz.questions)||c.quiz.questions.length<c.quiz.questionCount)throw Error('Hibás tesztbeállítás.');c.quiz.questions.forEach(question);return c;
 }
 function grade(questions,responses,passPercent){if(!Array.isArray(questions)||!questions.length)throw Error('Üres teszt.');let correct=0;const details=questions.map(q=>{const selected=responses[q.id]||[];if(!Array.isArray(selected)||new Set(selected).size!==selected.length||selected.some(v=>!q.answers.some(a=>a.id===v)))throw Error('Érvénytelen válasz.');const key=q.answers.filter(a=>a.correct).map(a=>a.id);const ok=selected.length===key.length&&key.every(a=>selected.includes(a));if(ok)correct++;return {questionId:q.id,correct:ok,explanation:q.explanation};});const percent=Math.round(correct/questions.length*100);return {correct,total:questions.length,percent,passed:correct/questions.length*100>=passPercent,details};}
 function lessons(course){return course.modules.flatMap(m=>m.lessons);}
 function progress(course,completed){const valid=new Set(lessons(course).map(l=>l.id));const count=new Set(completed.filter(x=>valid.has(x))).size;return {completed:count,total:valid.size,percent:Math.round(count/valid.size*100)};}
 function memoryAdapter(){const records=new Map();return {read(ctx){if(!ctx.userId||!ctx.organizationId)throw Error('Hiányzó felhasználói vagy szervezeti környezet.');const key=JSON.stringify([ctx.organizationId,ctx.userId,ctx.courseId,ctx.version]);if(!records.has(key))records.set(key,{completed:[],attempts:[]});return records.get(key);},clear(){records.clear();}};}
 return {validate,grade,lessons,progress,memoryAdapter};
});
