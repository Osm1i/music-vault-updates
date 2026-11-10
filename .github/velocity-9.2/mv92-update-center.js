/* Music Vault Vanguard 9.2 — Update Center polish and reliable install UX */
(() => {
  'use strict';
  if (window.__mv92UpdateCenterLoaded) return;
  window.__mv92UpdateCenterLoaded = true;

  const INSTALL_TEXT = /\binstall(?:\s+update)?\b|\bapply\s+update\b/i;
  let installRunning = false;
  let hideQueued = false;

  function toast(message, error = false) {
    let node = document.getElementById('mv92-update-toast');
    if (!node) {
      node = document.createElement('div');
      node.id = 'mv92-update-toast';
      Object.assign(node.style, {
        position: 'fixed', left: '50%', bottom: 'calc(28px + env(safe-area-inset-bottom))',
        transform: 'translateX(-50%)', zIndex: '2147483000', maxWidth: 'min(92vw, 520px)',
        padding: '13px 18px', borderRadius: '16px', background: '#24251f',
        color: '#f7f3e8', boxShadow: '0 12px 36px rgba(0,0,0,.32)',
        font: '600 14px/1.45 system-ui, sans-serif', textAlign: 'center',
        border: '1px solid rgba(216,195,143,.34)'
      });
      document.body.appendChild(node);
    }
    node.textContent = message;
    node.style.borderColor = error ? '#c76a63' : 'rgba(216,195,143,.34)';
    node.hidden = false;
  }

  function hideTechnicalSettings() {
    const fieldPattern = /(casaos|github\s*path|github\s*token|personal access token|release repository|repository path|update source credentials)/i;
    for (const el of document.querySelectorAll('label,p,span,small,strong,h3,h4,legend,div')) {
      if (el.closest('#mv92-update-toast')) continue;
      const text = (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
      if (!text || text.length > 130 || !fieldPattern.test(text)) continue;
      let container = el.closest('.form-group,.setting-row,.settings-row,.setting-item,.field-row,.form-field,.input-group');
      if (!container) container = el.parentElement;
      if (!container || container === document.body || container === document.documentElement) continue;
      const controls = container.querySelectorAll('button,[role="button"]');
      const hasInstall = Array.from(controls).some(button => INSTALL_TEXT.test(button.innerText || button.textContent || ''));
      if (!hasInstall) {
        container.hidden = true;
        container.setAttribute('aria-hidden', 'true');
      }
    }
    for (const form of document.querySelectorAll('form')) {
      const text = (form.innerText || '').replace(/\s+/g, ' ').trim();
      if (!/(casaos|github\s*path|github\s*token|personal access token)/i.test(text)) continue;
      if (INSTALL_TEXT.test(text)) continue;
      form.hidden = true;
      form.setAttribute('aria-hidden', 'true');
    }
  }

  function scheduleHide() {
    if (hideQueued) return;
    hideQueued = true;
    const run = () => { hideQueued = false; hideTechnicalSettings(); };
    if ('requestAnimationFrame' in window) requestAnimationFrame(run);
    else setTimeout(run, 20);
  }

  async function getStatus() {
    const response = await fetch('/api/updates/status', {
      method: 'GET', cache: 'no-store', credentials: 'same-origin'
    });
    if (!response.ok) throw new Error('Update status returned HTTP ' + response.status);
    return response.json();
  }

  function compareVersions(a, b) {
    const left = String(a || '0').split('.').map(Number);
    const right = String(b || '0').split('.').map(Number);
    for (let i = 0; i < 3; i++) {
      const diff = (left[i] || 0) - (right[i] || 0);
      if (diff) return diff;
    }
    return 0;
  }

  async function waitForInstall(button) {
    const deadline = Date.now() + 240000;
    let sawRestart = false;
    while (Date.now() < deadline) {
      await new Promise(resolve => setTimeout(resolve, 2200));
      try {
        const status = await getStatus();
        if (status.installed_version && status.latest_version &&
            compareVersions(status.installed_version, status.latest_version) >= 0) {
          toast('Update installed. Refreshing Music Vault…');
          setTimeout(() => window.location.reload(), 1300);
          return;
        }
        if (status.state === 'error') {
          toast(status.message || status.error || 'The update could not be installed.', true);
          if (button) button.disabled = false;
          installRunning = false;
          return;
        }
        if (/install|restart|download/i.test(String(status.state || ''))) {
          toast(status.message || 'Installing the update. Keep Music Vault open…');
        }
      } catch (_) {
        sawRestart = true;
        toast('Music Vault is restarting. Waiting for the update health check…');
      }
    }
    toast(sawRestart
      ? 'The server restarted, but the final version check timed out. Refresh Music Vault to confirm.'
      : 'The install is taking longer than expected. Check Update Center again in a moment.', true);
    if (button) button.disabled = false;
    installRunning = false;
  }

  async function startInstall(button) {
    if (installRunning) return;
    installRunning = true;
    if (button) button.disabled = true;
    toast('Starting the Music Vault installer…');
    try {
      const response = await fetch('/api/updates/install', {
        method: 'POST', credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' }, body: '{}'
      });
      let result = {};
      try { result = await response.json(); } catch (_) {}
      if (!response.ok) {
        throw new Error(result.error || result.message || ('Install request returned HTTP ' + response.status));
      }
      toast('Install started. Music Vault will restart when it is finished…');
      await waitForInstall(button);
    } catch (error) {
      toast(error.message || 'Could not start the installer.', true);
      if (button) button.disabled = false;
      installRunning = false;
    }
  }

  document.addEventListener('click', event => {
    const button = event.target && event.target.closest
      ? event.target.closest('button,[role="button"],a') : null;
    if (!button) return;
    const label = (button.innerText || button.textContent || '').replace(/\s+/g, ' ').trim();
    if (!INSTALL_TEXT.test(label) || !/install|update/i.test(label)) return;
    event.preventDefault();
    event.stopPropagation();
    if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
    startInstall(button);
  }, true);

  function start() {
    scheduleHide();
    const observer = new MutationObserver(scheduleHide);
    observer.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();

  window.MusicVaultUpdateCenter = Object.freeze({ version: '9.2.0' });
})();
