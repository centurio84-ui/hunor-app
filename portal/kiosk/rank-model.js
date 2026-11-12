(function(scope){
 const cohorts={mixed:{title:'Korábbi vegyes játék · 10 kérdés',count:10},'kiosk/children':{title:'Iskolás és gyerek mód · 5 kérdés',count:5},'kiosk/public':{title:'Lakossági biztonság · 8 kérdés',count:8},'kiosk/pro':{title:'HUNOR Pro kihívás · 10 kérdés',count:10}};
 function validate(rows,cohort){
  if(!cohorts[cohort]||!Array.isArray(rows))throw Error('Ismeretlen ranglista.');
  for(let i=0;i<rows.length;i++){
   const row=rows[i];if(!Number.isInteger(row.rank)||row.rank<1||row.total!==cohorts[cohort].count||!Number.isInteger(row.correct)||row.correct<0||row.correct>row.total||row.lrc!==row.correct*10)throw Error('A ranglista adatai nem ellenőrizhetők.');
   if(i>0&&(rows[i-1].lrc<row.lrc||rows[i-1].rank>row.rank))throw Error('A ranglista sorrendje hibás.');
  }
  return rows;
 }
 const api={cohorts,validate};if(typeof module==='object'&&module.exports)module.exports=api;else scope.HunorQuizRank=api;
})(typeof window==='undefined'?globalThis:window);
