/* Music Vault 9.24.1 — reliable Home refresh, Albums shortcut, and benign Safari error recovery. */
(() => {
  'use strict';
  if (window.__mv9241HomeRepair) return;
  window.__mv9241HomeRepair = true;
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  let repairTimer = null;
  let repairAttempts = 0;

  function activeHome() {
    return !!$('#page-home')?.classList.contains('active');
  }

  function repairRecentAdded(force = false) {
    const page = $('#page-home');
    const recent = $('#recentAlbums');
    if (!page || !recent) return;
    recent.hidden = false;
    recent.removeAttribute('aria-hidden');
    const section = recent.closest('.music-section');
    if (section) section.hidden = false;
    const cardCount = $$('.mv710-album-card', recent).length;
    if (cardCount || recent.querySelector('.empty')) recent.classList.add('mv710-recent-grid');

    // Always ask the existing 7.10 renderer for data when the album host has
    // no cards. The renderer owns API/data state; this patch only recovers it.
    const renderer = window.MusicVault710?.renderHomeAlbums;
    if (!cardCount && activeHome() && typeof renderer === 'function') {
      try {
        const result = renderer(true);
        if (result && typeof result.catch === 'function') {
          result.catch(err => console.warn('[Music Vault 9.24.1] Home albums refresh:', err));
        }
      } catch (err) {
        console.warn('[Music Vault 9.24.1] Home albums refresh:', err);
      }
    }
    return { cardCount, rendererReady: typeof renderer === 'function', force };
  }

  function scheduleHomeRepair(reset = false) {
    if (reset) repairAttempts = 0;
    if (repairTimer) clearTimeout(repairTimer);
    const delays = [250, 850, 1800, 3200];
    const delay = delays[Math.min(repairAttempts, delays.length - 1)];
    repairTimer = setTimeout(() => {
      repairTimer = null;
      repairAttempts += 1;
      repairRecentAdded(true);
    }, delay);
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
    const button = event.target?.closest?.('#page-home .music-section .section-title .text-action, #page-home .music-section .section-title button, #page-home [data-mv78-view-all]');
    if (!button) return;
    const section = button.closest('.music-section, .mv78-recent-added');
    const heading = $('.section-title h2', section)?.textContent?.trim().toLowerCase()
      || $('.mv78-section-head h2', section)?.textContent?.trim().toLowerCase()
      || '';
    const label = (button.textContent || '').trim().toLowerCase();
    if (!(heading.includes('recently added') || button.hasAttribute('data-mv78-view-all')) ||
        !(/view all|see all/.test(label) || button.hasAttribute('data-mv78-view-all'))) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    Promise.resolve(window.mvGoPage?.('library'))
      .then(() => {
        if (typeof window.mvLibraryTab === 'function') return window.mvLibraryTab('albums');
      })
      .catch(err => console.warn('[Music Vault 9.24.1] Recently Added navigation:', err));
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

  if (typeof window.mv923ClearPlayer === 'function' && !window.mv923ClearPlayer.__mv9241Wrapped) {
    const originalClear = window.mv923ClearPlayer;
    const wrappedClear = function (...args) {
      const result = originalClear.apply(this, args);
      scheduleHomeRepair(true);
      return result;
    };
    wrappedClear.__mv9241Wrapped = true;
    window.mv923ClearPlayer = wrappedClear;
  }

  document.addEventListener('click', openRecentlyAddedAlbums, true);
  document.addEventListener('click', event => {
    if (event.target?.closest?.('.mobile-nav [data-page="home"]')) scheduleHomeRepair(true);
  }, true);
  document.addEventListener('DOMContentLoaded', () => scheduleHomeRepair(true), { once: true });
  window.addEventListener('pageshow', () => scheduleHomeRepair(true), { passive: true });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => scheduleHomeRepair(true), { once: true });
  } else {
    repairRecentAdded(true);
    scheduleHomeRepair(true);
  }

  window.MusicVault9241 = {
    version: '9.24.1',
    repairRecentAdded,
    audit: () => ({
      homeActive: activeHome(),
      recentContainer: !!$('#recentAlbums'),
      recentGrid: !!$('#recentAlbums.mv710-recent-grid'),
      recentCards: $$('#recentAlbums .mv710-album-card').length,
      primaryTabs: $$('.mobile-nav button[data-page]').map(button => button.dataset.page),
      moreTab: !!$('.mobile-nav .mvbi-more-tab')
    })
  };
})();
