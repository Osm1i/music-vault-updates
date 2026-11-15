/* Music Vault 9.24.0 — home-feed layout recovery and stable tab shortcuts. */
(() => {
  'use strict';
  if (window.__mv924HomeRepair) return;
  window.__mv924HomeRepair = true;
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  let repairQueued = false;

  function activeHome() {
    return !!$('#page-home')?.classList.contains('active');
  }

  function repairRecentAdded() {
    const page = $('#page-home');
    const recent = $('#recentAlbums');
    if (!page || !recent) return;
    const section = recent.closest('.music-section');
    if (section) section.hidden = false;
    recent.hidden = false;
    recent.removeAttribute('aria-hidden');
    if ($$('.mv710-album-card', recent).length || recent.querySelector('.empty')) {
      recent.classList.add('mv710-recent-grid');
      recent.removeAttribute('data-mv710-error');
    } else if (activeHome()) {
      const renderer = window.MusicVault710?.renderHomeAlbums;
      if (typeof renderer === 'function') Promise.resolve(renderer(true)).catch(err => console.warn('[Music Vault 9.24] Home album retry:', err));
    }
  }

  function clearStaleHomeBanner() {
    const page = $('#page-home');
    if (!page) return;
    for (const banner of $$('.mv77-error-banner', page)) {
      const text = (banner.textContent || '').replace(/\s+/g, ' ').trim();
      if (/Home could not finish loading\.\s*The object can not be found here\.?/i.test(text)) banner.remove();
    }
  }

  function isBenignDetachedObjectError(reason) {
    const name = String(reason?.name || '');
    const message = String(reason?.message || reason || '').replace(/^NotFoundError:\s*/i, '').trim();
    return name === 'NotFoundError' && /^the object can not be found here\.?$/i.test(message);
  }

  function openRecentlyAddedAlbums(event) {
    const button = event.target?.closest?.('#page-home .music-section .section-title .text-action, #page-home .music-section .section-title button');
    if (!button) return;
    const section = button.closest('.music-section');
    const heading = $('.section-title h2', section)?.textContent?.trim().toLowerCase() || '';
    const label = (button.textContent || '').trim().toLowerCase();
    if (!heading.includes('recently added') || !/view all|see all/.test(label)) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    Promise.resolve(window.mvGoPage?.('library'))
      .then(() => {
        if (typeof window.openLibraryHubCategory === 'function') window.openLibraryHubCategory('albums');
        else if (typeof window.mvLibraryTab === 'function') return window.mvLibraryTab('albums');
      })
      .catch(err => console.warn('[Music Vault 9.24] Recently Added navigation:', err));
  }

  window.addEventListener('unhandledrejection', event => {
    if (!activeHome() || !isBenignDetachedObjectError(event.reason)) return;
    event.preventDefault();
    clearStaleHomeBanner();
    queueMicrotask(clearStaleHomeBanner);
    setTimeout(clearStaleHomeBanner, 0);
  });

  const home = $('#page-home');
  if (home && window.MutationObserver) {
    const bannerObserver = new MutationObserver(clearStaleHomeBanner);
    bannerObserver.observe(home, { childList: true, subtree: true, characterData: true });
  }

  if (typeof window.mv923ClearPlayer === 'function' && !window.mv923ClearPlayer.__mv924Wrapped) {
    const originalClear = window.mv923ClearPlayer;
    const wrappedClear = function (...args) {
      const result = originalClear.apply(this, args);
      setTimeout(repairRecentAdded, 80);
      setTimeout(repairRecentAdded, 420);
      return result;
    };
    wrappedClear.__mv924Wrapped = true;
    window.mv923ClearPlayer = wrappedClear;
  }

  document.addEventListener('click', openRecentlyAddedAlbums, true);
  document.addEventListener('DOMContentLoaded', repairRecentAdded, { once: true });
  window.addEventListener('pageshow', repairRecentAdded, { passive: true });
  document.addEventListener('click', event => {
    if (event.target?.closest?.('#mvBottomIsland .mobile-nav [data-page="home"]')) {
      setTimeout(repairRecentAdded, 120);
      setTimeout(repairRecentAdded, 650);
    }
  }, true);

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', repairRecentAdded, { once: true });
  else repairRecentAdded();

  window.MusicVault924 = {
    version: '9.24.0',
    repairRecentAdded,
    audit: () => ({
      homeActive: activeHome(),
      recentContainer: !!$('#recentAlbums'),
      recentGrid: !!$('#recentAlbums.mv710-recent-grid'),
      recentCards: $$('#recentAlbums .mv710-album-card').length,
      primaryTabs: $$('#mvBottomIsland .mobile-nav button[data-page]').map(b => b.dataset.page),
      moreTab: !!$('#mvBottomIsland .mobile-nav .mvbi-more-tab')
    })
  };
})();
