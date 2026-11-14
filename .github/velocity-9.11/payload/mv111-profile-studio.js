(()=> {
 'use strict';

 const VERSION='9.11.0';
 const norm=value=>String(value||'').replace(/\s+/g,' ').trim().toLocaleLowerCase();
 const visible=el=>{
  if(!el||!el.isConnected)return false;
  const style=getComputedStyle(el),rect=el.getBoundingClientRect();
  return style.display!=='none'&&style.visibility!=='hidden'&&rect.width>0&&rect.height>0;
 };
 const SELECTABLE='button,[role="button"],a,[onclick],li,div';
 const ACTION='button,[role="button"],a,[onclick]';
 let familyCache={at:0,names:[],active:''};
 let lastSignature='';
 let currentModal=null;
 let tagged=[];
 let busy=false;

 function mark(el,cls){
  if(!el||!el.classList||el.classList.contains(cls))return;
  el.classList.add(cls);
  tagged.push([el,cls]);
 }
 function clear(){
  for(const [el,cls] of tagged){
   if(el&&el.classList)el.classList.remove(cls);
  }
  tagged=[];
  if(currentModal){
   currentModal.querySelectorAll('[data-mv111-badge="1"]').forEach(el=>el.remove());
   currentModal.querySelectorAll('[data-mv111-original-label]').forEach(el=>{
    el.textContent=el.getAttribute('data-mv111-original-label')||el.textContent;
    el.removeAttribute('data-mv111-original-label');
   });
  }
  currentModal=null;
  lastSignature='';
 }
 async function getFamily(){
  if(Date.now()-familyCache.at<4000&&familyCache.names.length)return familyCache;
  try{
   const response=await fetch('/api/family',{credentials:'same-origin',cache:'no-store'});
   if(!response.ok)throw new Error('Family profile list unavailable');
   const data=await response.json();
   const names=(Array.isArray(data.members)?data.members:[])
    .map(item=>String(item&&item.name||'').trim())
    .filter(Boolean);
   if(names.length){
    familyCache={at:Date.now(),names,active:String(data.active||data.active_member||'').trim()};
   }
  }catch(_){}
  return familyCache;
 }
 function textOf(el){return norm(el&&('innerText'in el?el.innerText:el.textContent));}
 function matchingName(el,names){
  const txt=textOf(el);
  if(!txt||txt.length>180)return '';
  return names.find(name=>{
   const n=norm(name);
   return txt===n||txt.startsWith(n+' ')||txt.startsWith(n+'·')||txt.startsWith(n+'—');
  })||'';
 }
 function closestAction(el){
  return el.closest(ACTION)||el;
 }
 function cardFor(el,name,names,modal){
  let node=closestAction(el),best=node;
  const modalRect=modal.getBoundingClientRect();
  const modalArea=Math.max(1,modalRect.width*modalRect.height);
  for(let step=0;step<5;step++){
   const parent=best.parentElement;
   if(!parent||parent===modal||parent===document.body)break;
   const txt=textOf(parent);
   if(!txt.includes(norm(name))||names.some(other=>other!==name&&txt.includes(norm(other))))break;
   const r=parent.getBoundingClientRect();
   const area=Math.max(0,r.width*r.height);
   if(txt.length<=220&&area<modalArea*.58&&parent.children.length<=12)best=parent;
   else break;
  }
  return best;
 }
 function branchAt(node,ancestor){
  let branch=node;
  while(branch&&branch.parentElement&&branch.parentElement!==ancestor)branch=branch.parentElement;
  return branch&&branch.parentElement===ancestor?branch:null;
 }
 function findGrid(nodes,modal){
  if(nodes.length<2)return null;
  let ancestor=nodes[0].parentElement;
  while(ancestor&&ancestor!==modal&&ancestor!==document.body){
   const branches=nodes.map(node=>branchAt(node,ancestor));
   if(branches.every(Boolean)&&new Set(branches).size===nodes.length&&ancestor.children.length<=nodes.length+5){
    return {root:ancestor,branches};
   }
   ancestor=ancestor.parentElement;
  }
  return null;
 }
 function exactTextNodes(root,phrase){
  const wanted=norm(phrase);
  return Array.from(root.querySelectorAll('h1,h2,h3,h4,h5,h6,p,small,strong,span,div,section,header,button,a,li'))
   .filter(el=>visible(el)&&textOf(el)===wanted);
 }
 function hideLegacyCopy(modal,names){
  // Remove duplicate/empty helper sections from the old chooser. Only exact,
  // non-interactive copy is hidden; existing profile and edit actions remain.
  for(const el of exactTextNodes(modal,'Welcome back')){
   if(!el.querySelector('button,input,select,textarea'))mark(el,'mv111-hide');
  }
  for(const el of exactTextNodes(modal,'Choose your profile')){
   let target=el.parentElement||el;
   if(target!==modal&&!target.querySelector(ACTION+' ,input,select,textarea')&&
      !names.some(name=>textOf(target).includes(norm(name))))mark(target,'mv111-hide');
   else mark(el,'mv111-hide');
  }
  for(const el of exactTextNodes(modal,'Your listening identities')){
   mark(el,'mv111-hide');
  }
  for(const el of Array.from(modal.querySelectorAll('button,[role="button"],a,[onclick]'))){
   const txt=textOf(el);
   if(txt==='customize current'||txt==='replay intro'||txt==='replay intro ↗'){
    mark(el,'mv111-hide');
    const parent=el.parentElement;
    if(parent&&parent!==modal&&parent.children.length<=3){
     const siblings=Array.from(parent.children);
     if(siblings.length&&siblings.every(s=>{
      const v=textOf(s);
      return !v||v==='customize current'||v==='replay intro'||v==='replay intro ↗';
     }))mark(parent,'mv111-hide');
    }
   }
  }
  for(const el of Array.from(modal.querySelectorAll('small,p,span,div'))){
   const txt=textOf(el);
   if((txt==='your music. your space.'||txt==='music vault · your music. your space.')&&el.children.length<=2){
    mark(el.parentElement&&el.parentElement!==modal?el.parentElement:el,'mv111-brand');
   }
  }
  const descriptions=Array.from(modal.querySelectorAll('p')).filter(visible);
  for(const p of descriptions){
   const txt=textOf(p);
   if(txt.includes('choose a listening space to continue')||txt.includes('choose a listening space')){
    if(!p.hasAttribute('data-mv111-original-label')){
     p.setAttribute('data-mv111-original-label',p.textContent||'');
     p.textContent='Choose a profile and jump straight into your music.';
    }
   }
  }
 }
 function addCurrentBadge(card){
  if(card.querySelector('[data-mv111-badge="1"]'))return;
  const badge=document.createElement('span');
  badge.className='mv111-current-badge';
  badge.setAttribute('data-mv111-badge','1');
  badge.textContent='CURRENT';
  card.appendChild(badge);
 }
 function styleEditActions(card){
  for(const el of Array.from(card.querySelectorAll('button,[role="button"],a,[onclick]'))){
   const label=norm(el.getAttribute('aria-label')||el.getAttribute('title')||el.textContent);
   if(/edit|customi[sz]e|rename/.test(label)||/^[✎✏🖉]$/.test((el.textContent||'').trim())){
    mark(el,'mv111-edit-action');
   }
  }
 }
 async function enhance(){
  if(busy)return;
  busy=true;
  try{
   const veil=Array.from(document.querySelectorAll('.profileveil')).find(visible);
   if(!veil){if(currentModal)clear();return;}
   const modal=veil.querySelector('.profilemodal')||veil;
   const family=await getFamily();
   const names=family.names;
   if(!names.length){if(currentModal)clear();return;}
   const title=Array.from(modal.querySelectorAll('h1,h2,h3')).find(el=>/who.?s listening|who.?s listenin/.test(textOf(el)));
   if(!title){if(currentModal)clear();return;}
   const signature=names.join('|')+'|'+family.active+'|'+textOf(modal);
   if(currentModal===modal&&signature===lastSignature)return;
   if(currentModal)clear();
   currentModal=modal;
   lastSignature=signature;

   mark(veil,'mv111-profile-veil');
   mark(modal,'mv111-profile-modal');
   mark(title,'mv111-title');

   hideLegacyCopy(modal,names);

   const profileNodes=Array.from(modal.querySelectorAll(SELECTABLE))
    .filter(el=>visible(el)&&matchingName(el,names));
   const cards=[];
   for(const name of names){
    const matches=profileNodes.filter(el=>matchingName(el,[name]));
    if(!matches.length)continue;
    matches.sort((a,b)=>textOf(a).length-textOf(b).length);
    const card=cardFor(matches[0],name,names,modal);
    if(!cards.some(item=>item.name===name)){
     const active=family.active&&norm(family.active)===norm(name);
     const legacyCurrent=textOf(card).includes('current profile');
     cards.push({name,card,active:!!active||legacyCurrent});
    }
   }
   if(!cards.length){clear();return;}
   for(const item of cards){
    mark(item.card,'mv111-grid-item');
    mark(item.card,'mv111-person-card');
    if(item.active){mark(item.card,'mv111-is-current');addCurrentBadge(item.card);}
    styleEditActions(item.card);
   }

   const addMatches=Array.from(modal.querySelectorAll(SELECTABLE))
    .filter(el=>{
     if(!visible(el))return false;
     const txt=textOf(el);
     return txt.length<180&&(/^(add|new|create)\s+(profile|person)\b/.test(txt)||
       /^(add|new|create)\s+(profile|person)\b/.test(norm(el.getAttribute('aria-label')||'')));
    });
   let addCard=null;
   if(addMatches.length){
    addMatches.sort((a,b)=>textOf(a).length-textOf(b).length);
    addCard=cardFor(addMatches[0],'add profile',names,modal);
    mark(addCard,'mv111-grid-item');
    mark(addCard,'mv111-add-person');
   }

   const gridNodes=cards.map(x=>x.card);
   if(addCard&&!gridNodes.includes(addCard))gridNodes.push(addCard);
   const grid=findGrid(gridNodes,modal);
   if(grid){
    mark(grid.root,'mv111-profile-grid');
    grid.branches.forEach(branch=>mark(branch,'mv111-grid-item'));
    for(const sibling of Array.from(grid.root.children)){
     if(grid.branches.includes(sibling))continue;
     if(/^hr$/i.test(sibling.tagName)||!textOf(sibling))mark(sibling,'mv111-hide');
    }
   }else{
    const parent=cards[0].card.parentElement;
    if(parent&&parent!==modal&&cards.every(item=>parent.contains(item.card))){
     mark(parent,'mv111-profile-grid');
    }
   }
   // Existing profile edit and add handlers are untouched; only their layout changes.
   if(addCard)styleEditActions(addCard);
  }catch(_){
   // A failed enhancement must never block the original profile picker.
  }finally{busy=false;}
 }
 let queued=false;
 function schedule(){
  if(queued)return;
  queued=true;
  requestAnimationFrame(()=>{queued=false;enhance();});
 }
 const observer=new MutationObserver(schedule);
 observer.observe(document.documentElement,{subtree:true,childList:true,attributes:true,attributeFilter:['class','style','aria-hidden']});
 document.addEventListener('click',()=>setTimeout(schedule,30),true);
 window.addEventListener('resize',schedule,{passive:true});
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',schedule,{once:true});
 schedule();
})();