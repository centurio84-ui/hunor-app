window.MadChiefShare = {
  async create(data) {
    const canvas=document.createElement('canvas');canvas.width=1200;canvas.height=630;
    const c=canvas.getContext('2d');if(!c)throw Error('A képkészítés nem támogatott.');
    c.fillStyle='#101b23';c.fillRect(0,0,1200,630);c.strokeStyle='#ff852b';c.lineWidth=6;c.strokeRect(24,24,1152,582);
    c.textAlign='center';c.fillStyle='#ff852b';c.font='bold 30px system-ui';c.fillText('RESCUE PLATFORM · HUNOR',600,95);
    c.fillStyle='#ffffff';c.font='bold 42px system-ui';c.fillText(data.quizName,600,165,1060);
    c.fillStyle='#ff852b';c.font='bold 82px system-ui';c.fillText(`${Math.round(data.percent)}%`,600,285);
    c.fillStyle='#ffffff';c.font='bold 34px system-ui';c.fillText(`${data.symbol} ${data.title}`,600,365,1060);
    c.font='28px system-ui';c.fillText(`${data.score} / ${data.total*10} pont`,600,422);
    if(data.name)c.fillText(data.name,600,470,1000);
    c.fillStyle='#bac6ce';c.font='22px system-ui';c.fillText('Ismeretterjesztő tudáspróba · hun01usar.hu/kiosk/',600,550);
    return new Promise((resolve,reject)=>canvas.toBlob(blob=>blob?resolve(blob):reject(Error('A kép nem készíthető el.')),'image/png'));
  }
};
