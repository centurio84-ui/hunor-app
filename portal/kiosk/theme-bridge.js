/* Read only presentation tokens from the existing same-origin portal theme.
   Standalone quiz keeps its own accessible rescue palette. No credentials/storage. */
(() => {
  if(parent===window)return;
  let source;
  try {source=parent.document.documentElement;}catch{return;}
  const allowed=['--page','--surface','--accent','--text','--muted'];
  function sync(){
    const values=parent.getComputedStyle(source);
    for(const token of allowed){const color=values.getPropertyValue(token).trim();
      if(color && CSS.supports('color',color))document.documentElement.style.setProperty(token,color);
      else document.documentElement.style.removeProperty(token);
    }
  }
  const observer=new MutationObserver(sync);
  observer.observe(source,{attributes:true,attributeFilter:['data-hunor-theme','class','style']});
  window.addEventListener('pagehide',()=>observer.disconnect(),{once:true});sync();
})();
