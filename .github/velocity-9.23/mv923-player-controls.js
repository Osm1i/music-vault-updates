/* Music Vault 9.23.0 — persistent favorite heart state and mini-player clear action. */
(() => {
  'use strict';

  const audio = document.getElementById('mvAudio');
  const favoriteCache = { profile: '', ids: new Set(), loadedAt: 0, pending: null };
  const CACHE_MS = 12000;

  function profileName() {
    return localStorage.getItem('mv_profile') || 'Owner';
  }

  function currentTrackId() {
    const source = audio?.getAttribute('src') || audio?.currentSrc || audio?.src || '';
    const match = String(source).match(/\/api\/stream\/(\d+)(?:[/?#]|$)/);
    return match ? Number(match[1]) : 0;
  }

  function setHeart(button, favorite) {
    if (!button) return;
    button.classList.toggle('is-favorite', !!favorite);
    button.setAttribute('aria-pressed', favorite ? 'true' : 'false');
    button.textContent = favorite ? '♥' : '♡';
    button.title = favorite ? 'Remove from Favorites' : 'Add to Favorites';
  }

  function syncVisibleFavoriteButtons(ids = favoriteCache.ids) {
    document.querySelectorAll('button[onclick]').forEach((button) => {
      const handler = button.getAttribute('onclick') || '';
      const match = handler.match(/togglePersonalFavorite\(\s*(\d+)\s*\)/);
      if (!match) return;
      const id = Number(match[1]);
      const favorite = ids.has(id);
      button.dataset.mv923FavoriteControl = '1';
      button.classList.toggle('is-favorite', favorite);
      button.setAttribute('aria-pressed', favorite ? 'true' : 'false');
      button.title = favorite ? 'Remove from Favorites' : 'Add to Favorites';
      if (/♡|♥/.test(button.textContent || '')) {
        const glyph = favorite ? '♥' : '♡';
        if (button.textContent.trim() !== glyph) button.textContent = glyph;
      }
    });
  }

  function setFavoriteState(trackId, favorite) {
    const id = Number(trackId || 0);
    const currentId = currentTrackId();
    if (id && currentId === id) {
      setHeart(document.getElementById('miniLike'), favorite);
      setHeart(document.getElementById('nowFavorite'), favorite);
    }
    if (!id) {
      setHeart(document.getElementById('miniLike'), false);
      setHeart(document.getElementById('nowFavorite'), false);
    }
    if (id) syncVisibleFavoriteButtons(new Set(favorite ? [...favoriteCache.ids, id] : [...favoriteCache.ids].filter(x => x !== id)));
  }

  async function loadFavoriteIds(force = false) {
    const profile = profileName();
    const fresh = favoriteCache.profile === profile &&
      (Date.now() - favoriteCache.loadedAt) < CACHE_MS;
    if (!force && fresh) return favoriteCache.ids;
    if (!force && favoriteCache.pending && favoriteCache.profile === profile) {
      return favoriteCache.pending;
    }
    favoriteCache.profile = profile;
    favoriteCache.pending = (async () => {
      const response = await fetch('/api/personal/' + encodeURIComponent(profile) + '/favorites', {
        method: 'GET',
        headers: { Accept: 'application/json' },
        cache: 'no-store'
      });
      let data = {};
      try { data = await response.json(); } catch (_) {}
      if (!response.ok) throw new Error(data.error || 'Could not read Favorites.');
      favoriteCache.ids = new Set((Array.isArray(data.items) ? data.items : []).map((item) => Number(item.id)));
      favoriteCache.loadedAt = Date.now();
      syncVisibleFavoriteButtons(favoriteCache.ids);
      return favoriteCache.ids;
    })();
    try {
      return await favoriteCache.pending;
    } finally {
      favoriteCache.pending = null;
    }
  }

  async function syncFavoriteState(trackId) {
    const id = Number(trackId || currentTrackId() || 0);
    if (!id) {
      setFavoriteState(0, false);
      return;
    }
    try {
      const ids = await loadFavoriteIds();
      // Ignore a late response after the user has moved to another song/profile.
      if (currentTrackId() === id) setFavoriteState(id, ids.has(id));
    } catch (_) {
      // A temporary read failure must not block playback or favorite controls.
    }
  }

  window.mv923SetFavoriteState = setFavoriteState;
  window.mv923SyncFavoriteState = syncFavoriteState;
  window.mv923RefreshFavoriteStates = async function () {
    favoriteCache.loadedAt = 0;
    try {
      const ids = await loadFavoriteIds(true);
      syncVisibleFavoriteButtons(ids);
      await syncFavoriteState(currentTrackId());
    } catch (_) {}
  };

  // Keep hearts correct after list views are re-rendered with fresh buttons.
  if (window.MutationObserver && document.body) {
    let syncScheduled = false;
    const observer = new MutationObserver(() => {
      if (syncScheduled) return;
      syncScheduled = true;
      window.requestAnimationFrame(() => {
        syncScheduled = false;
        if (favoriteCache.profile === profileName() && favoriteCache.loadedAt) {
          syncVisibleFavoriteButtons(favoriteCache.ids);
        } else {
          loadFavoriteIds().then(syncVisibleFavoriteButtons).catch(() => {});
        }
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  // The existing server route already toggles per-profile favorites and returns {favorite:boolean}.
  // Keep that route as the source of truth, then refresh the active heart from the GET result.
  const originalToggleFavorite = window.togglePersonalFavorite;
  if (typeof originalToggleFavorite === 'function') {
    window.togglePersonalFavorite = async function (trackId) {
      const id = Number(trackId || 0);
      const result = await originalToggleFavorite.apply(this, arguments);
      favoriteCache.loadedAt = 0;
      if (id) {
        try {
          const ids = await loadFavoriteIds(true);
          setFavoriteState(id, ids.has(id));
        } catch (_) {}
      }
      return result;
    };
  }

  // Avoid the legacy duplicate toast and update the same favorite state in mini and expanded players.
  window.toggleCurrentFavorite = async function () {
    const id = currentTrackId();
    if (!id || typeof window.togglePersonalFavorite !== 'function') return;
    return window.togglePersonalFavorite(id);
  };

  // Refresh all visible hearts after the active listening profile changes.
  const originalSelectProfile = window.selectProfile;
  if (typeof originalSelectProfile === 'function') {
    window.selectProfile = async function () {
      const result = await originalSelectProfile.apply(this, arguments);
      await window.mv923RefreshFavoriteStates();
      return result;
    };
  }

  // The miniClear button calls the private player clear API directly through its inline handler.
  // Clearing playback never deletes audio files or library/database records.

  loadFavoriteIds().then(syncVisibleFavoriteButtons).catch(() => {});
  syncFavoriteState(currentTrackId());
})();
