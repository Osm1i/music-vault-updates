(()=> {
 'use strict';
 const VERSION='9.12.0';
 const OVERLAY_ID='mv112-profile-studio-overlay';
 const norm=value=>String(value||'').replace(/\s+/g,' ').trim().toLocaleLowerCase();
 const visible=el=>{
  if(!el||!el.isConnected)return false;
  const s=getComputedStyle(el),r=el.getBoundingClientRect();
  return s.display!=='none'&&s.visibility!=='hidden'&&r.width>0&&r.height>0;
 };
 const text=el=>norm(el&&('innerText'in el?el.innerText:el.textContent));
 let busy=false,queued=false,lastRoot=null,suspended=false;
 async function family(){
  const r=await fetch('/api/family',{credentials:'same-origin',cache:'no-store'});
  if(!r.ok)throw new Error('Music Vault profiles could not be loaded');
  const d=await r.json();
  const members=(Array.isArray(d.members)?d.members:[])
   .map(m=>({name:String(m.name||'').trim(),color:String(m.color||'').trim(),id:m.id}))
   .filter(m=>m.name);
  if(!members.length)throw new Error('No saved profiles were returned');
  return {members,active:String(d.active||d.active_member||'').trim()};
 }
 function findHeading(){
  const all=Array.from(document.querySelectorAll('h1,h2,h3,h4,[role="heading"],[class*="heading"],[class*="title"],div,span'))
   .filter(visible)
   .filter(el=>/who.?s listening/.test(text(el))&&text(el).length<90);
  all.sort((a,b)=>text(a).length-text(b).length);
  return all[0]||null;
 }
 function visibleEditor(){
  return Array.from(document.querySelectorAll('input:not([type="hidden"]),textarea,select'))
   .some(el=>visible(el));
 }
 function openLegacyAction(action){
  if(!action)return;
  suspended=true;
  removeOverlay();
  setTimeout(()=>{
   action.click();
   setTimeout(()=>{
    if(!visibleEditor()){suspended=false;schedule();}
   },900);
  },30);
 }
 function findScope(heading,members){
  const names=members.map(m=>norm(m.name));
  let node=heading;
  for(let i=0;node&&node!==document.body&&i<10;i++,node=node.parentElement){
   const t=text(node);
   if(names.every(n=>t.includes(n))&&t.includes('add profile'))return node;
  }
  const modal=heading.closest('.profilemodal,.profileveil,[role="dialog"],.modal');
  if(modal&&modal!==document.body)return modal;
  node=heading;
  for(let i=0;node&&node!==document.body&&i<5;i++,node=node.parentElement){
   if(node.children.length>1)return node;
  }
  return null;
 }
 function findProfileRoot(scope,name,members){
  const key=norm(name),allNames=members.map(m=>norm(m.name));
  const candidates=Array.from(scope.querySelectorAll('button,[role="button"],a,[onclick],li,div,article,section'))
   .filter(el=>visible(el))
   .filter(el=>{
    const t=text(el);
    return t.startsWith(key)&&t.length<240&&!allNames.some(n=>n!==key&&t.includes(n));
   });
  candidates.sort((a,b)=>text(a).length-text(b).length);
  let node=candidates[0]||null;
  if(!node){
   const leaves=Array.from(scope.querySelectorAll('span,strong,b,p,h3,h4'))
    .filter(el=>visible(el)&&text(el)===key);
   node=leaves[0]||null;
  }
  if(!node)return null;
  let best=node,cur=node;
  for(let i=0;cur&&cur!==scope&&i<7;i++,cur=cur.parentElement){
   const t=text(cur);
   if(!t.includes(key)||allNames.some(n=>n!==key&&t.includes(n)))break;
   if(t.length<=260)best=cur;
  }
  return best;
 }
 function findAction(root,kind){
  if(!root)return null;
  const selectors='button,[role="button"],a,[onclick],div[tabindex],li[tabindex]';
  const all=Array.from(root.querySelectorAll(selectors)).filter(visible);
  const match=all.filter(el=>{
   const t=text(el);
   const label=norm(el.getAttribute('aria-label')||el.getAttribute('title')||'');
   if(kind==='edit')return /^(edit|rename|customize|customise)\b/.test(t)||/edit|rename|customi[sz]e/.test(label)||/^[✎✏🖉]$/.test((el.textContent||'').trim());
   return /^(add|new|create)\s+(profile|person)\b/.test(t)||/add (profile|person)/.test(label);
  });
  match.sort((a,b)=>text(a).length-text(b).length);
  if(match.length)return match[0];
  if(kind==='edit'){
   const small=Array.from(root.querySelectorAll('button,[role="button"],a,[onclick]')).filter(visible);
   const glyph=small.find(el=>/^[✎✏🖉]$/.test((el.textContent||'').trim()));
   if(glyph)return glyph;
  }else{
   const fallback=Array.from(root.querySelectorAll('button,div,li,article,section'))
    .filter(visible)
    .filter(el=>/^(add|new|create)\s+(profile|person)\b/.test(text(el))&&text(el).length<180);
   fallback.sort((a,b)=>text(a).length-text(b).length);
   if(fallback.length)return fallback[0];
  }
  return null;
 }
 function makeAvatar(root,member){
  const wrap=document.createElement('div');
  wrap.className='mv112-avatar';
  wrap.style.setProperty('--profile-color',member.color||'#b89a5b');
  let source=null;
  if(root)source=root.querySelector('img,svg,[class*="avatar"],[class*="profile-art"],[class*="profile-icon"]');
  if(source){
   const clone=source.cloneNode(true);
   clone.removeAttribute('id');
   clone.classList.add('mv112-avatar-content');
   clone.removeAttribute('onclick');
   wrap.appendChild(clone);
  }else{
   const initials=member.name.trim().split(/\s+/).slice(0,2).map(x=>Array.from(x)[0]||'').join('').toUpperCase();
   const fallback=document.createElement('span');
   fallback.textContent=initials||'♪';
   fallback.className='mv112-avatar-fallback';
   wrap.appendChild(fallback);
  }
  return wrap;
 }
 function makeCard(member,scope,active,members){
  const root=findProfileRoot(scope,member.name,members);
  const edit=findAction(root,'edit');
  const isCurrent=!!active||(!!root&&text(root).includes('current profile'));
  const card=document.createElement('article');
  card.className='mv112-profile-card'+(isCurrent?' is-current':'');
  const select=document.createElement('button');
  select.type='button';select.className='mv112-select';
  select.setAttribute('aria-label','Listen as '+member.name);
  const avatar=makeAvatar(root,member);
  const info=document.createElement('span');info.className='mv112-profile-info';
  const name=document.createElement('strong');name.className='mv112-name';name.textContent=member.name;
  const status=document.createElement('small');status.className='mv112-status';status.textContent=isCurrent?'Currently listening':'Personal listening space';
  info.append(name,status);
  const arrow=document.createElement('span');arrow.className='mv112-arrow';arrow.textContent='›';arrow.setAttribute('aria-hidden','true');
  select.append(avatar,info,arrow);
  select.addEventListener('click',async()=>{
   select.disabled=true;select.classList.add('is-loading');
   try{
    const response=await fetch('/api/profile/active',{
     method:'POST',credentials:'same-origin',cache:'no-store',
     headers:{'Content-Type':'application/json'},
     body:JSON.stringify({member:member.name})
    });
    if(!response.ok)throw new Error('Could not switch to '+member.name);
    removeOverlay();
    window.location.reload();
   }catch(error){
    select.disabled=false;select.classList.remove('is-loading');
    const message=document.querySelector('#mv112-profile-studio-overlay .mv112-error');
    if(message)message.textContent=error.message||'Could not switch profiles. Try again.';
    // Use the existing profile card handler as a fallback if the legacy
    // profile endpoint has a different response contract.
    const legacy=findProfileRoot(scope,member.name,members);
    if(legacy&&legacy!==select)legacy.click();
   }
  });
  card.appendChild(select);
  if(isCurrent){
   const badge=document.createElement('span');badge.className='mv112-current';badge.textContent='CURRENT';card.appendChild(badge);
  }
  if(edit){
   const pencil=document.createElement('button');pencil.type='button';pencil.className='mv112-edit';
   pencil.setAttribute('aria-label','Edit '+member.name+' profile');pencil.textContent='✎';
   pencil.addEventListener('click',()=>openLegacyAction(edit));
   card.appendChild(pencil);
  }
  return card;
 }
 function removeOverlay(){
  const old=document.getElementById(OVERLAY_ID);
  if(old)old.remove();
  lastRoot=null;
 }
 function makeAddTile(addAction){
  const card=document.createElement('button');card.type='button';card.className='mv112-add-card';
  const plus=document.createElement('span');plus.className='mv112-plus';plus.textContent='+';
  const title=document.createElement('strong');title.textContent='Add a person';
  const sub=document.createElement('small');sub.textContent='Create another listening space';
  card.append(plus,title,sub);
  card.addEventListener('click',()=>openLegacyAction(addAction));
  return card;
 }
 function render(data,scope,heading){
  removeOverlay();
  const veil=document.createElement('div');veil.id=OVERLAY_ID;veil.className='mv112-overlay';
  veil.setAttribute('role','dialog');veil.setAttribute('aria-modal','true');veil.setAttribute('aria-label',"Who's listening?");
  const panel=document.createElement('main');panel.className='mv112-panel';
  const top=document.createElement('header');top.className='mv112-top';
  const brand=document.createElement('div');brand.className='mv112-brand';
  const logo=document.createElement('span');logo.className='mv112-brand-icon';logo.textContent='♫';
  const brandText=document.createElement('span');brandText.textContent='MUSIC VAULT';
  brand.append(logo,brandText);
  const count=document.createElement('span');count.className='mv112-count';
  count.textContent=data.members.length+' '+(data.members.length===1?'PROFILE':'PROFILES');
  top.append(brand,count);
  const intro=document.createElement('section');intro.className='mv112-intro';
  const eyebrow=document.createElement('div');eyebrow.className='mv112-eyebrow';eyebrow.textContent='YOUR SHARED MUSIC SPACE';
  const title=document.createElement('h1');title.textContent="Who's listening?";
  const desc=document.createElement('p');desc.textContent='Pick your profile. Your music is shared, your listening stays personal.';
  intro.append(eyebrow,title,desc);
  const list=document.createElement('section');list.className='mv112-list';list.setAttribute('aria-label','Family profiles');
  const grid=document.createElement('div');grid.className='mv112-grid';
  data.members.forEach(member=>{
   const active=data.active?norm(data.active)===norm(member.name):false;
   grid.appendChild(makeCard(member,scope,active,data.members));
  });
  const addAction=findAction(scope,'add');
  if(addAction)grid.appendChild(makeAddTile(addAction));
  list.appendChild(grid);
  const footer=document.createElement('footer');footer.className='mv112-footer';
  const note=document.createElement('span');note.textContent='One tap to start listening.';
  const error=document.createElement('span');error.className='mv112-error';error.setAttribute('role','status');
  footer.append(note,error);
  panel.append(top,intro,list,footer);
  veil.appendChild(panel);
  document.body.appendChild(veil);
  lastRoot=scope;
  // Keep keyboard users inside the visible first action without adding a new step.
  const first=grid.querySelector('.mv112-select');
  if(first)setTimeout(()=>first.focus({preventScroll:true}),50);
 }
 async function scan(){
  if(busy||suspended||visibleEditor()||document.getElementById(OVERLAY_ID))return;
  busy=true;
  try{
   const heading=findHeading();
   if(!heading){lastRoot=null;return;}
   const data=await family();
   if(document.getElementById(OVERLAY_ID))return;
   const scope=findScope(heading,data.members);
   if(!scope)return;
   if(scope===lastRoot)return;
   render(data,scope,heading);
  }catch(_){
   // If the new picker cannot initialise, the original Music Vault UI stays available.
  }finally{busy=false;}
 }
 function schedule(){
  if(queued)return;
  queued=true;
  requestAnimationFrame(()=>{queued=false;scan();});
 }
 const observer=new MutationObserver(schedule);
 observer.observe(document.documentElement,{subtree:true,childList:true,attributes:true,attributeFilter:['class','style','aria-hidden']});
 document.addEventListener('click',event=>{
  const action=event.target&&event.target.closest&&event.target.closest('button,[role="button"],a');
  const label=action?text(action):'';
  if(/^(save|done|cancel|close|update|confirm)\b/.test(label)){
   setTimeout(()=>{suspended=false;schedule();},450);
  }
 },true);
 document.addEventListener('keydown',event=>{
  if(event.key==='Escape'&&suspended){setTimeout(()=>{suspended=false;schedule();},250);}
 });
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',schedule,{once:true});
 schedule();
})();