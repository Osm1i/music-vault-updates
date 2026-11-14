(()=> {
 'use strict';
 const normalize=s=>String(s||'').replace(/\s+/g,' ').trim().toLocaleLowerCase();
 const visible=el=>{
  if(!el||!el.isConnected)return false;
  const style=getComputedStyle(el),r=el.getBoundingClientRect();
  return style.display!=='none'&&style.visibility!=='hidden'&&r.width>0&&r.height>0;
 };
 let cache={at:0,names:[]},queued=false;
 async function getNames(){
  if(Date.now()-cache.at<5000)return cache.names;
  try{
   const response=await fetch('/api/family',{credentials:'same-origin',cache:'no-store'});
   if(!response.ok)throw new Error('Family profiles are unavailable');
   const data=await response.json();
   cache={at:Date.now(),names:(data.members||[]).map(x=>String(x.name||'').trim()).filter(Boolean)};
  }catch(_){}
  return cache.names;
 }
 const nearestAction=el=>el.closest('button,[role="button"],a,[onclick]')||el;
 async function enhance(){
  const veil=Array.from(document.querySelectorAll('.profileveil')).find(visible);
  if(!veil)return;
  const modal=veil.querySelector('.profilemodal')||veil;
  const names=await getNames();
  if(!names.length)return;
  const modalText=normalize(modal.innerText);
  const titlePresent=/who.?s listening|choose (a )?profile|select (a )?profile/.test(modalText);
  const nameNodes=Array.from(modal.querySelectorAll('button,[role="button"],a,[onclick],div,li'))
   .filter(el=>visible(el)&&names.some(name=>{
    const t=normalize(el.innerText||el.textContent);
    return t===normalize(name)||(t.startsWith(normalize(name)+' ')&&t.length<90);
   }))
   .map(nearestAction);
  const cards=[...new Set(nameNodes)].filter(el=>{
   const t=normalize(el.innerText||el.textContent);
   return names.some(name=>t===normalize(name)||(t.startsWith(normalize(name)+' ')&&t.length<90));
  });
  if(!titlePresent&&!cards.length)return;

  veil.classList.add('mv101-profile-veil');
  modal.classList.add('mv101-profile-modal');
  const title=modal.querySelector('h1,h2,h3');
  if(title&&/who.?s listening|choose (a )?profile|select (a )?profile/i.test(title.textContent)){
   title.classList.add('mv101-profile-title');
  }
  cards.forEach(card=>card.classList.add('mv101-person-card'));
  if(cards.length>=2){
   const parents=cards.map(x=>x.parentElement).filter(Boolean);
   const common=parents.length&&parents.every(p=>p===parents[0])?parents[0]:null;
   if(common)common.classList.add('mv101-profile-grid');
  }
  const add=Array.from(modal.querySelectorAll('button,[role="button"],a,[onclick]'))
   .find(el=>visible(el)&&/^(add|new|create)\s+(person|profile)|^add\s*\+/i.test(normalize(el.innerText||el.textContent))||
    /add (person|profile)/i.test(String(el.getAttribute('aria-label')||'')));
  if(add)add.classList.add('mv101-add-person');

  // Existing add/edit controls stay wired to the original Music Vault actions.
  // This layer only gives the chooser a consistent, responsive layout.
  modal.classList.add('mv101-profile-ready');
 }
 function schedule(){
  if(queued)return;
  queued=true;
  requestAnimationFrame(()=>{queued=false;enhance();});
 }
 const observer=new MutationObserver(schedule);
 observer.observe(document.documentElement,{subtree:true,childList:true,attributes:true,attributeFilter:['class','style','aria-hidden']});
 document.addEventListener('click',()=>setTimeout(schedule,0),true);
 window.addEventListener('resize',schedule,{passive:true});
 document.addEventListener('DOMContentLoaded',schedule);
 schedule();
})();