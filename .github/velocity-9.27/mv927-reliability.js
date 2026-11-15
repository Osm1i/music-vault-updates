/* Music Vault 9.27.0 — Reliability Center and safe playlist management. */
(()=>{
 'use strict';
 const $=id=>document.getElementById(id);
 const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const api=async(url,options={})=>{const r=await fetch(url,options);let d={};try{d=await r.json()}catch{}if(!r.ok)throw new Error(d.error||`Request failed (${r.status})`);return d};
 const member=()=>window.activeProfile||localStorage.getItem('mv_profile')||'Owner';
 const fmtBytes=n=>{n=Number(n)||0;if(n>=1024**4)return (n/1024**4).toFixed(1)+' TB';if(n>=1024**3)return (n/1024**3).toFixed(1)+' GB';if(n>=1024**2)return (n/1024**2).toFixed(1)+' MB';return Math.round(n/1024)+' KB'};
 const setDot=(id,ok)=>{const x=$(id);if(x)x.classList.toggle('is-good',!!ok)};
 async function loadReliability(){
  const footer=$('mv927Footer');
  try{
   const d=await api('/api/maintenance/overview');
   const metrics=$('mv927Metrics');
   if(metrics)metrics.innerHTML=[
    ['APP SERVICE',d.service||'Unknown',String(d.service||'').toLowerCase()==='active'||String(d.service||'').toLowerCase()==='running'],
    ['DATABASE',fmtBytes(d.database?.size_bytes),true],
    ['FREE STORAGE',`${d.storage?.free_gb??'—'} GB`,(d.storage?.free_bytes||0)>2*1024**3],
    ['DOWNLOAD QUEUE',`${d.counts?.queued??0} active`,true]
   ].map(x=>`<div class="mv927-metric"><small>${x[0]}</small><strong class="${x[2]?'good':'warn'}">${esc(x[1])}</strong></div>`).join('');
   const b=d.latest_backup;
   if($('mv927BackupStatus'))$('mv927BackupStatus').innerHTML=b?`Last verified backup <b>${esc(b.age_hours)} hours ago</b><br><span>${esc(b.name)} · ${fmtBytes(b.size_bytes)} · ${Number(d.backup_count)||0} retained</span>`:'No backup found yet. Daily backups start automatically.';
   if($('mv927DownloadBackup'))$('mv927DownloadBackup').hidden=!b;
   setDot('mv927BackupDot',!!b && Number(b.age_hours)<30);
   const lib=d.library||{};
   if($('mv927LibraryStatus'))$('mv927LibraryStatus').innerHTML=`<div><b>${Number(d.counts?.tracks)||0}</b><span>tracks indexed</span></div><div><b>${Number(lib.duplicate_sha_groups)||0}</b><span>duplicate-file groups</span></div><div><b>${Number(lib.duplicate_metadata_groups)||0}</b><span>same-metadata groups</span></div><div><b>${Number(lib.missing_file_count)||0}</b><span>missing files ${lib.missing_file_scan_truncated?'(sampled)':''}</span></div>`;
   setDot('mv927LibraryDot',!(lib.missing_file_count||lib.duplicate_sha_groups));
   const y=d.youtube||{};
   if($('mv927YoutubeStatus'))$('mv927YoutubeStatus').innerHTML=`<b>${y.runtime_ready?'JavaScript runtime ready':'JavaScript runtime needs setup'}</b><br><span>${esc(y.runtime||'Not detected')}</span><br><span>Concurrent fragments are adapted to available CPU/RAM; failed fragments are retried and partial files can resume.</span><br><span class="mv927-path">Private cookies file: ${esc(y.cookies_path||'not configured')}</span><br><span>${y.cookies_configured?'Cookies file detected.':'No YouTube session cookies configured.'}</span>`;
   setDot('mv927YoutubeDot',!!y.runtime_ready);
   if(footer)footer.textContent='Updated '+new Date().toLocaleTimeString()+' · Diagnostics are read-only; the re-index action only scans existing music.';
  }catch(e){if(footer)footer.textContent='Could not load diagnostics: '+e.message; if($('mv927Metrics'))$('mv927Metrics').innerHTML=`<div class="mv927-error">${esc(e.message)}</div>`;}
 }
 window.mv927LoadReliability=loadReliability;
 $('mv927Refresh')?.addEventListener('click',loadReliability);
 $('mv927BackupNow')?.addEventListener('click',async()=>{const b=$('mv927BackupNow');b.disabled=true;b.textContent='Creating backup…';try{const d=await api('/api/maintenance/backup',{method:'POST'});if(window.toast)toast(d.message||'Backup created.');await loadReliability()}catch(e){if(window.toast)toast(e.message);if($('mv927Footer'))$('mv927Footer').textContent=e.message}finally{b.disabled=false;b.textContent='Back up now'}});
 $('mv927ScanLibrary')?.addEventListener('click',async()=>{const b=$('mv927ScanLibrary');b.disabled=true;b.textContent='Starting scan…';try{const d=await api('/api/maintenance/library-scan',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({member:member()})});if(window.toast)toast(d.message||'Library scan started.')}catch(e){if(window.toast)toast(e.message)}finally{b.disabled=false;b.textContent='Re-index library safely';setTimeout(loadReliability,1200)}});
 const oldGo=window.mvGoPage;
 if(typeof oldGo==='function')window.mvGoPage=async function(name){const out=await oldGo.apply(this,arguments);if(name==='settings')loadReliability();return out};

 // The legacy profile renderer emits a playlist-opening button. Wrap it in a small
 // card and add a separate delete action without nested buttons or changing open behavior.
 function attachPlaylistDelete(){
  const host=$('profileOwnedPlaylists');if(!host)return;
  host.querySelectorAll('button.playlisttile').forEach(card=>{
   if(card.dataset.mv927Wired==='1')return;
   const attr=card.getAttribute('onclick')||'';const found=attr.match(/openPersonalPlaylist\((\d+)/);if(!found)return;
   const id=Number(found[1]);if(!Number.isFinite(id)||id<1)return;
   card.dataset.mv927Wired='1';
   const wrap=document.createElement('div');wrap.className='mv927-playlist-wrap';
   card.parentNode.insertBefore(wrap,card);wrap.appendChild(card);
   const del=document.createElement('button');del.type='button';del.className='mv927-delete-playlist';del.textContent='Delete';del.setAttribute('aria-label','Delete playlist');
   del.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();window.mv927DeletePlaylist(id)});
   wrap.appendChild(del);
  });
 }
 const playlistHost=$('profileOwnedPlaylists');
 if(playlistHost){
  const observer=new MutationObserver(()=>attachPlaylistDelete());
  observer.observe(playlistHost,{childList:true,subtree:true});
  attachPlaylistDelete();
 }
 window.mv927DeletePlaylist=async id=>{
  const card=playlistHost?.querySelector(`[data-mv927-wired="1"][onclick^="openPersonalPlaylist(${Number(id)},"]`);
  const name=card?.querySelector('b')?.textContent?.replace(/^♫\s*/,'')||'this playlist';
  if(!confirm(`Delete “${name}” from ${member()}’s playlists? The songs remain in your music library.`))return;
  try{
   await api(`/api/personal/${encodeURIComponent(member())}/playlists/${Number(id)}`,{method:'DELETE'});
   if(window.toast)toast('Playlist deleted. Your music files were not changed.');
   if(typeof window.loadProfileDashboard==='function')await window.loadProfileDashboard();
   attachPlaylistDelete();
  }catch(e){if(window.toast)toast(e.message)}
 };
})();
