(function (scope) {
  'use strict';
  const messages = {
    welcome: ['Szia! MAD Chief vagyok! Készen állsz, hogy próbára tedd a tudásodat?', 'Üdv a csapatban! Ma együtt tanulunk a biztonságról.'],
    question: ['Figyeld meg a lehetőségeket, és válassz megfontoltan!', 'Új feladat következik. A tudásod a legjobb felszerelésed.'],
    correct: ['Kiváló döntés! Szép munka!', 'Pontosan! Egy lépéssel felkészültebb lettél.'],
    wrong: ['Ebből is tanulhatsz! Nézzük meg együtt a helyes megoldást.', 'Most a tanulásé a főszerep. Olvasd el a magyarázatot!'],
    timeout: ['Lejárt az idő. Most nyugodtan nézzük át a megoldást!'],
    finish: ['Küldetés teljesítve! Nézzük, mit tanultál.']
  };
  function speech(kind, index = 0) {const list=messages[kind] || messages.welcome; return list[Math.abs(index)%list.length];}
  function grade(correct, total) {
    const percent = total > 0 ? Math.max(0,Math.min(100,correct/total*100)) : 0;
    const tier = percent >= 80 ? 'leader' : percent >= 50 ? 'citizen' : 'rookie';
    return {percent, tier, title: {leader:'Tiszteletbeli Mentővezető',citizen:'Tudatos Állampolgár',rookie:'Kiképzésre váró Újonc'}[tier], symbol: {leader:'★',citizen:'◆',rookie:'▲'}[tier]};
  }
  function education(question) {
    const custom=question.didYouKnow;
    // Imported custom advice requires an explicit professional review marker.
    if(custom && typeof custom==='object' && custom.reviewStatus==='approved' && typeof custom.text==='string' && custom.text.trim()) {
      const image=typeof custom.image==='string' && /^\/kiosk\/assets\/[a-zA-Z0-9/_-]+\.(webp|png|jpg)$/.test(custom.image) ? custom.image : null;
      return {title: String(custom.title || 'TUDTAD?'), text:custom.text, image, imageAlt:String(custom.imageAlt||'A magyarázathoz kapcsolódó illusztráció')};
    }
    return typeof question.explanation==='string' && question.explanation.trim() ? {title:'TUDTAD?',text:question.explanation,image:null} : null;
  }
  function shareData({correct,total,score,name,includeName=false,quizName='Veszélyhelyzeti Kvíz'}) {
    return {quizName,score,total,...grade(correct,total),...(includeName ? {name:String(name||'').slice(0,30)} : {})};
  }
  const api={speech,grade,education,shareData};
  if(typeof module==='object' && module.exports) module.exports=api; else scope.MadChief=api;
})(typeof window==='undefined'?globalThis:window);
