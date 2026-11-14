(()=> {
 'use strict';
 const VERSION='9.13.0';
 const OVERLAY_ID='mv113-profile-studio';
 const BODY_CLASS='mv113-profile-studio-active';
 const norm=value=>String(value||'').replace(/\s+/g,' ').trim().toLocaleLowerCase();
 const visible=el=>{
  if(!el||!el.isConnected)return false;
  const s=getComputedStyle(el),r=el.getBoundingClientRect();
  return s.display!=='none'&&s.visibility!=='hidden'&&r.width>0&&r.height>0;
 };
 const text=el=>norm(el&&('innerText'in el?el.innerText:el.textContent));
 let busy=false,queued=false,suspended=false,shown=false,suspendUntil=0;

 async function getFamily(){
  const response=await fetch('/api/family',{credentials:'same-origin',cache:'no-store'});
  if(!response.ok)throw new Error('Could not load family profiles');
  const data=await response.json();
  const members=(Array.isArray(data.members)?data.members:[])
   .map(item=>({name:String(item.name||'').trim(),color:String(item.color||'').trim(),id:item.id}))
   .filter(item=>item.name);
  if(!members.length)throw new Error('No family profiles were returned');
  return {members,active:String(data.active||data.active_member||'').trim()};
 }
 function nativeVeil(){
  return Array.from(document.querySelectorAll('.profileveil')).find(el=>visible(el)&&
   el.querySelector('.profilemodal,[class*="profilemodal"],h1,h2,h3,[role="heading"]'))||null;
 }
 function findHeading(veil){
  const root=veil.querySelector('.profilemodal')||veil;
  const candidates=Array.from(root.querySelectorAll('h1,h2,h3,h4,[role="heading"],div,span'))
   .filter(el=>visible(el)&&/who.?s listening/.test(text(el))&&text(el).length<100);
  candidates.sort((a,b)=>text(a).length-text(b).length);
  return candidates[0]||null;
 }
 function findScope(heading,veil,members){
  const names=members.map(item=>norm(item.name));
  let node=heading;
  for(let i=0;node&&node!==veil&&i<10;i++,node=node.parentElement){
   const value=text(node);
   if(names.every(name=>value.includes(name)))return node;
  }
  return veil.querySelector('.profilemodal')||veil;
 }
 function findProfileRoot(scope,name,members){
  const key=norm(name),otherNames=members.map(item=>norm(item.name)).filter(item=>item!==key);
  const candidates=Array.from(scope.querySelectorAll('button,[role="button"],a,[onclick],li,div,article,section'))
   .filter(el=>visible(el))
   .filter(el=>{
    const value=text(el);
    return (value===key||value.startsWith(key+' ')||value.startsWith(key+'·')||value.startsWith(key+'—'))&&
     value.length<240&&!otherNames.some(other=>value.includes(other));
   });
  candidates.sort((a,b)=>text(a).length-text(b).length);
  let node=candidates[0]||null;
  if(!node){
   node=Array.from(scope.querySelectorAll('span,strong,b,p,h3,h4'))
    .find(el=>visible(el)&&text(el)===key)||null;
  }
  if(!node)return null;
  let best=node,cur=node;
  for(let i=0;cur&&cur!==scope&&cur!==veilRoot(scope)&&i<6;i++,cur=cur.parentElement){
   const value=text(cur);
   if(!value.includes(key)||otherNames.some(other=>value.includes(other))||value.length>260)break;
   best=cur;
  }
  return best;
 }
 function veilRoot(scope){
  return scope.closest('.profilemodal')||scope.closest('.profileveil')||null;
 }
 function findAction(root,kind){
  if(!root)return null;
  const all=Array.from(root.querySelectorAll('button,[role="button"],a,[onclick],div[tabindex],li[tabindex]'))
   .filter(visible);
  const matches=all.filter(el=>{
   const value=text(el);
   const label=norm(el.getAttribute('aria-label')||el.getAttribute('title')||'');
   if(kind==='edit')return /^(edit|rename|customize|customise)\b/.test(value)||
    /edit|rename|customi[sz]e/.test(label)||/^[✎✏🖉]$/.test((el.textContent||'').trim());
   return /^(add|new|create)\s+(profile|person)\b/.test(value)||/add (profile|person)/.test(label);
  });
  matches.sort((a,b)=>text(a).length-text(b).length);
  if(matches.length)return matches[0];
  if(kind==='add'){
   const fallback=Array.from(root.querySelectorAll('button,div,li,article,section'))
    .filter(visible).filter(el=>/^(add|new|create)\s+(profile|person)\b/.test(text(el))&&text(el).length<180);
   fallback.sort((a,b)=>text(a).length-text(b).length);
   return fallback[0]||null;
  }
  return null;
 }
 function selectableTarget(root,scope){
  if(!root)return null;
  let node=root;
  for(let i=0;node&&node!==scope&&i<5;i++,node=node.parentElement){
   if(node.matches&&node.matches('button,[role="button"],a,[onclick]'))return node;
  }
  const inner=Array.from(root.querySelectorAll('button,[role="button"],a,[onclick]'))
   .filter(visible)
   .filter(el=>!/edit|rename|customi[sz]e/.test(norm(el.getAttribute('aria-label')||el.title||'')));
  if(inner.length)return inner[0];
  return root;
 }
 function makeAvatar(root,member){
  const avatar=document.createElement('span');
  avatar.className='mv113-avatar';
  if(member.color)avatar.style.setProperty('--mv113-avatar-color',member.color);
  const source=root&&root.querySelector('img,[class*="avatar"],[class*="profile-icon"],svg');
  if(source){
   const clone=source.cloneNode(true);
   clone.removeAttribute('id');clone.removeAttribute('onclick');
   clone.classList.add('mv113-avatar-image');
   avatar.appendChild(clone);
  }else{
   const initials=member.name.trim().split(/\s+/).slice(0,2).map(part=>Array.from(part)[0]||'').join('').toUpperCase();
   const fallback=document.createElement('span');
   fallback.className='mv113-avatar-fallback';fallback.textContent=initials||'♪';
   avatar.appendChild(fallback);
  }
  return avatar;
 }
 function editorOpen(){
  return Array.from(document.querySelectorAll('input:not([type="hidden"]),textarea,select')).some(visible);
 }
 function resumeAfterEditor(){
  if(!suspended||Date.now()<suspendUntil||editorOpen())return;
  suspended=false;shown=false;
  schedule();
 }
 function openLegacyAction(action){
  if(!action)return;
  suspended=true;
  suspendUntil=Date.now()+1000;
  const overlay=document.getElementById(OVERLAY_ID);
  if(overlay)overlay.remove();
  document.body.classList.remove(BODY_CLASS);
  setTimeout(()=>action.click(),40);
  setTimeout(resumeAfterEditor,1100);
 }
 function activateExistingProfile(action,select,feedback){
  if(!action){feedback.textContent='This profile is unavailable. Please try again.';return;}
  select.disabled=true;select.classList.add('is-loading');
  // Invoke Music Vault's own profile-card handler. Do not perform a second
  // API request or reload the page (which restarts the intro animation).
  try{action.click();}
  catch(_){
   select.disabled=false;select.classList.remove('is-loading');
   feedback.textContent='Could not open that profile. Please try again.';
   return;
  }
  setTimeout(()=>{
   // Temporarily remove our hiding class to see whether Music Vault itself
   // closed its native chooser. The custom screen stays in place during this
   // synchronous check, so the old chooser never flashes back on screen.
   document.body.classList.remove(BODY_CLASS);
   const stillOpen=!!nativeVeil();
   if(stillOpen){
    document.body.classList.add(BODY_CLASS);
    select.disabled=false;select.classList.remove('is-loading');
    feedback.textContent='Music Vault did not switch profiles. Tap again to retry.';
   }else{
    const overlay=document.getElementById(OVERLAY_ID);
    if(overlay)overlay.remove();
    shown=false;
   }
  },900);
 }
 function profileCard(member,scope,family){
  const source=findProfileRoot(scope,member.name,family.members);
  const action=selectableTarget(source,scope);
  const edit=findAction(source,'edit');
  const active=family.active?norm(family.active)===norm(member.name):
   !!(source&&text(source).includes('current profile'));
  const card=document.createElement('article');
  card.className='mv113-profile-card'+(active?' is-current':'');
  const select=document.createElement('button');
  select.type='button';select.className='mv113-select';
  select.setAttribute('aria-label','Listen as '+member.name);
  select.appendChild(makeAvatar(source,member));
  const details=document.createElement('span');details.className='mv113-details';
  const name=document.createElement('strong');name.className='mv113-name';name.textContent=member.name;
  const state=document.createElement('small');state.className='mv113-state';
  state.textContent=active?'Current profile':'Personal listening space';
  details.append(name,state);
  const arrow=document.createElement('span');arrow.className='mv113-arrow';arrow.textContent='›';
  select.append(details,arrow);
  const feedback=document.createElement('span');feedback.className='mv113-card-error';feedback.setAttribute('role','status');
  select.addEventListener('click',()=>activateExistingProfile(action,select,feedback));
  card.append(select,feedback);
  if(active){
   const badge=document.createElement('span');badge.className='mv113-current';badge.textContent='CURRENT';
   card.appendChild(badge);
  }
  if(edit){
   const pencil=document.createElement('button');pencil.type='button';pencil.className='mv113-edit';
   pencil.setAttribute('aria-label','Edit '+member.name+' profile');pencil.textContent='✎';
   pencil.addEventListener('click',()=>openLegacyAction(edit));
   card.appendChild(pencil);
  }
  return card;
 }
 function addCard(action){
  if(!action)return null;
  const card=document.createElement('button');card.type='button';card.className='mv113-add-card';
  const plus=document.createElement('span');plus.className='mv113-plus';plus.textContent='+';
  const title=document.createElement('strong');title.textContent='Add a person';
  const hint=document.createElement('small');hint.textContent='Create another listening space';
  card.append(plus,title,hint);
  card.addEventListener('click',()=>openLegacyAction(action));
  return card;
 }
 function render(veil,scope,family){
  const old=document.getElementById(OVERLAY_ID);
  if(old)old.remove();
  const overlay=document.createElement('div');overlay.id=OVERLAY_ID;overlay.className='mv113-overlay';
  overlay.setAttribute('role','dialog');overlay.setAttribute('aria-modal','true');
  overlay.setAttribute('aria-label',"Who's listening?");
  const panel=document.createElement('main');panel.className='mv113-panel';
  const header=document.createElement('header');header.className='mv113-header';
  const brand=document.createElement('div');brand.className='mv113-brand';
  const icon=document.createElement('span');icon.className='mv113-brand-icon';icon.textContent='♫';
  const wordmark=document.createElement('span');wordmark.textContent='MUSIC VAULT';
  brand.append(icon,wordmark);
  const count=document.createElement('span');count.className='mv113-count';
  count.textContent=family.members.length+' PROFILES';
  header.append(brand,count);
  const intro=document.createElement('section');intro.className='mv113-intro';
  const eyebrow=document.createElement('span');eyebrow.className='mv113-eyebrow';eyebrow.textContent='YOUR SHARED MUSIC SPACE';
  const title=document.createElement('h1');title.textContent="Who's listening?";
  const subtitle=document.createElement('p');subtitle.textContent='Choose your profile and get straight to your music.';
  intro.append(eyebrow,title,subtitle);
  const grid=document.createElement('section');grid.className='mv113-grid';grid.setAttribute('aria-label','Listening profiles');
  family.members.forEach(member=>grid.appendChild(profileCard(member,scope,family)));
  const add=findAction(scope,'add');
  const addTile=addCard(add);if(addTile)grid.appendChild(addTile);
  const footer=document.createElement('footer');footer.className='mv113-footer';
  footer.textContent='One tap to start listening.';
  panel.append(header,intro,grid,footer);overlay.appendChild(panel);
  document.body.classList.add(BODY_CLASS);
  document.body.appendChild(overlay);
  shown=true;
  const first=grid.querySelector('.mv113-select');
  if(first)setTimeout(()=>first.focus({preventScroll:true}),30);
 }
 async function scan(){
  if(busy||suspended||shown||document.getElementById(OVERLAY_ID))return;
  busy=true;
  try{
   const veil=nativeVeil();
   if(!veil)return;
   const heading=findHeading(veil);
   if(!heading)return;
   const family=await getFamily();
   if(document.getElementById(OVERLAY_ID)||suspended||shown)return;
   const scope=findScope(heading,veil,family.members);
   if(!scope)return;
   render(veil,scope,family);
  }catch(_){
   // Leave the native Music Vault selector available if enhancement cannot initialise.
  }finally{busy=false;}
 }
 function schedule(){
  if(queued)return;
  queued=true;requestAnimationFrame(()=>{queued=false;scan();});
 }
 const observer=new MutationObserver(()=>{
  if(suspended&&Date.now()>=suspendUntil&&!editorOpen()){
   suspended=false;shown=false;document.body.classList.remove(BODY_CLASS);
  }
  schedule();
 });
 observer.observe(document.documentElement,{subtree:true,childList:true,attributes:true,attributeFilter:['class','style','aria-hidden']});
 document.addEventListener('click',()=>setTimeout(()=>{
  if(suspended)resumeAfterEditor();
  schedule();
 },500),true);
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',schedule,{once:true});
 schedule();
})();