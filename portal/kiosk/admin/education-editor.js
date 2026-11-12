/* Extends the existing lqEditQuestion modal; never creates another admin API. */
(function(scope){
  'use strict';
  const fields=[['education_title','TUDTAD-kártya címe','title',100],['education_text','Oktatókártya szövege','text',3000],['education_image','Helyi illusztráció útvonala','image',240],['education_image_alt','Illusztráció leírása','imageAlt',240]];
  function values(question){const card=question?.did_you_know||{};return Object.fromEntries(fields.map(([name,,key])=>[name,String(card[key]||'')]));}
  function cardForPublication(question){
    if(question?.status!=='approved'||!question.approved_at||!question.approved_by||!question.did_you_know)return null;
    const input=values(question);
    return {title:input.education_title,text:input.education_text,image:input.education_image||null,imageAlt:input.education_image_alt,reviewStatus:'approved'};
  }
  function install({questionAt,schemaReady=()=>false}){
    if(typeof scope.lqEditQuestion!=='function'||typeof questionAt!=='function')throw Error('A meglévő kérdésszerkesztő szükséges.');
    const previous=scope.lqEditQuestion;
    scope.lqEditQuestion=function(index){
      previous(index);
      const form=document.querySelector('#lqQuestionEdit'),q=questionAt(index);
      if(!form||form.querySelector('[data-education-editor]'))return;
      const group=document.createElement('fieldset');group.dataset.educationEditor='true';group.className='lq-wide';
      const legend=document.createElement('legend');legend.textContent='TUDTAD? oktatókártya';group.append(legend);
      if(!Object.hasOwn(q||{},'did_you_know')&&!schemaReady()){
        const notice=document.createElement('p');notice.textContent='Az oktatókártyák szerveres bővítése még nincs bekapcsolva. A meglévő magyarázat továbbra is szerkeszthető.';group.append(notice);
      }else{
        const current=values(q);
        for(const [name,label,key,max] of fields){
          const container=document.createElement('label');container.className='field';container.textContent=label;
          const input=document.createElement(key==='text'?'textarea':'input');input.name=name;input.value=current[name];input.maxLength=max;if(key==='text')input.rows=5;
          container.append(input);group.append(container);
        }
        const note=document.createElement('p');note.textContent='Üres kártyánál a meglévő magyarázat jelenik meg. Mentéskor új tervezet készül; közzétételhez szakmai jóváhagyás kell. A kép útvonala /kiosk/assets/ alatt legyen.';group.append(note);
      }
      form.insertBefore(group,form.querySelector('button[type="submit"]'));
    };
    return ()=>{scope.lqEditQuestion=previous;};
  }
  const api={values,cardForPublication,install};if(typeof module==='object'&&module.exports)module.exports=api;else scope.MadChiefEducationEditor=api;
})(typeof window==='undefined'?globalThis:window);
