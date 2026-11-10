/* Music Vault Vanguard 9.1 — Velocity Edition
   Native lazy loading, async decoding, and bounded DOM work for long libraries. */
(() => {
  'use strict';
  if (window.__mv91VelocityLoaded) return;
  window.__mv91VelocityLoaded = true;
  const root = document.documentElement;
  root.classList.add('mv91-velocity');

  const CARD_GRIDS = ['.album-grid','.albums-grid','.library-grid','.playlist-grid','.artist-grid','.music-grid','.card-grid'];
  const ROW_LISTS = ['.song-list','.songs-list','.track-list','.tracks-list','.queue-list','.library-list'];
  let queued = false;

  function nearFirstScreen(element) {
    const rect = element.getBoundingClientRect();
    return rect.bottom >= -120 && rect.top <= Math.max(window.innerHeight * 1.35, 900);
  }
  function optimizeImages(scope) {
    const images = [];
    if (scope && scope.nodeType === 1 && scope.matches?.('img')) images.push(scope);
    if (scope?.querySelectorAll) images.push(...scope.querySelectorAll('img:not([data-mv91-optimized])'));
    for (const img of images) {
      if (img.dataset.mv91Optimized) continue;
      img.dataset.mv91Optimized = '1';
      img.decoding = 'async';
      const critical = nearFirstScreen(img);
      img.loading = critical ? 'eager' : 'lazy';
      if ('fetchPriority' in img) img.fetchPriority = critical ? 'auto' : 'low';
    }
  }
  function optimizeLongCollections(scope) {
    if (!scope?.querySelectorAll) return;
    for (const selector of CARD_GRIDS) {
      for (const grid of scope.querySelectorAll(selector)) {
        for (let i = 8; i < grid.children.length; i++) grid.children[i].classList.add('mv91-velocity-card');
      }
    }
    for (const selector of ROW_LISTS) {
      for (const list of scope.querySelectorAll(selector)) {
        for (let i = 16; i < list.children.length; i++) list.children[i].classList.add('mv91-velocity-row');
      }
    }
  }
  function scan(scope) { optimizeImages(scope); optimizeLongCollections(scope); }
  function scheduleScan(node) {
    if (!node || queued) return;
    queued = true;
    const run = () => { queued = false; scan(node); };
    if ('requestAnimationFrame' in window) requestAnimationFrame(run);
    else setTimeout(run, 16);
  }
  function start() {
    scan(document);
    const observer = new MutationObserver(records => {
      for (const record of records) {
        for (const node of record.addedNodes) if (node.nodeType === 1) scheduleScan(node);
      }
    });
    observer.observe(document.documentElement, {childList:true, subtree:true});
    window.addEventListener('pageshow', () => scan(document), {once:true});
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true});
  else start();
  window.MusicVaultVelocity = Object.freeze({
    version:'9.1.0',
    description:'Native lazy media, async image decoding, and long-list rendering optimization'
  });
})();
