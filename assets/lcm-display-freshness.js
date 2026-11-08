/**
 * Standard Display revision delivery, port 9876 and IDE webview hosting.
 * Authors: Rolf, Copilot. Version: 10.0.2. Date: 2026-11-08 15:07:36.
 */
(function () {
  'use strict';
  const apiBase = (location.protocol === 'http:' && (location.hostname === '127.0.0.1' || location.hostname === 'localhost') && location.port === '9876')
    ? ''
    : 'http://127.0.0.1:9876';
  const displayId = document.querySelector('meta[name="lcm-display-id"]')?.content;
  if (!displayId) return; // Historical evidence viewers do not reconcile live data.
  const allowed = ['tools', 'rules', 'inventory', 'hub', 'dates'];
  if (!allowed.includes(displayId)) throw new Error('Unknown Standard Display identity.');
  const key = 'lcm-display-view:' + displayId;
  let revision = '';
  let presentation = document.querySelector('meta[name="lcm-presentation-revision"]')?.content || '';
  let busy = false;
  let requested = false;
  let stopped = false;
  let timer;
  const badge = document.createElement('div');
  badge.id = 'lcm-display-status';
  badge.setAttribute('role', 'status');
  Object.assign(badge.style, {
    position: 'fixed', bottom: '6px', right: '8px', zIndex: '100000',
    background: '#fff', color: '#333', border: '1px solid #888',
    borderRadius: '4px', padding: '5px 10px', font: '12px sans-serif',
    maxWidth: '75vw', whiteSpace: 'pre-wrap'
  });
  function show(state, detail) {
    badge.dataset.state = state;
    badge.textContent = state + (detail ? ' - ' + detail : '');
    badge.title = 'Last applied revision: ' + (revision || 'none verified');
  }
  function capture() {
    const fields = {};
    document.querySelectorAll('input[id],select[id],textarea[id]').forEach(el => {
      if (el.type !== 'password' && el.type !== 'file') fields[el.id] = { value: el.value, checked: el.checked };
    });
    return { fields, x: scrollX, y: scrollY, custom: window.LcmDisplayCaptureState?.() };
  }
  function restore(state) {
    if (!state) return;
    for (const [id, value] of Object.entries(state.fields || {})) {
      const el = document.getElementById(id);
      if (!el) continue;
      if (el.tagName !== 'SELECT' || Array.from(el.options).some(option => option.value === value.value)) el.value = value.value;
      if ('checked' in el) el.checked = value.checked;
    }
    window.LcmDisplayRestoreState?.(state.custom);
    window.scrollTo(state.x || 0, state.y || 0);
  }
  async function query(path, method = 'GET') {
    const url = path.startsWith('http') ? path : apiBase + path;
    const response = await fetch(url, { method, cache: 'no-store', signal: AbortSignal.timeout(10000) });
    if (!response.ok) {
      const error = new Error('HTTP ' + response.status + ' from ' + url + ': ' + await response.text());
      error.status = response.status;
      throw error;
    }
    return response;
  }
  async function reconcile(force = false) {
    requested ||= force;
    if (busy || stopped) return;
    busy = true;
    try {
      const isLoopback = location.protocol === 'http:' && (location.hostname === '127.0.0.1' || location.hostname === 'localhost') && location.port === '9876';
      const isWebview = location.protocol === 'vscode-webview:';
      if (!isLoopback && !isWebview) {
        stopped = true;
        throw new Error('Invalid delivery path. Open this Standard Display through http://127.0.0.1:9876 or inside Antigravity IDE only.');
      }
      const refresh = requested;
      requested = false;
      const response = await query('/displays/' + (refresh ? 'refresh/' : 'status/') + displayId, refresh ? 'POST' : 'GET');
      const status = await response.json();
      if (!['Current', 'Updating', 'Stale', 'Failed', 'Disconnected'].includes(status.state)) throw new Error('Invalid display publication status.');
      if (status.state === 'Current' && (!status.revision || !status.presentationRevision)) throw new Error('Current publication has no verified revision identity.');
      const applying = status.state === 'Current' && status.revision !== revision;
      show(applying ? 'Updating' : status.state, applying ? 'Applying published revision' : (status.error || status.publishedAt || 'Awaiting publication'));
      if (status.state !== 'Current' || !status.revision || status.revision === revision) return;
      if (presentation && status.presentationRevision !== presentation) {
        sessionStorage.setItem(key, JSON.stringify(capture()));
        location.reload(); // Only presentation transitions reload; data applies in place.
        return;
      }
      const published = await query('/displays/data/' + displayId);
      if (published.headers.get('X-LCM-Display-Revision') !== status.revision) {
        requested = false;
        show('Updating', 'A newer publication is available; reconciling.');
        return;
      }
      const data = await published.json();
      const content = '<script id="lcm-display-data" type="application/json">' +
        JSON.stringify(data).replace(/</g, '\\u003c') + '</script>';
      if (typeof window.LcmDisplayApply !== 'function') throw new Error('This display has no data revision adapter.');
      await window.LcmDisplayApply(content, status);
      revision = status.revision;
      presentation = status.presentationRevision;
      const saved = sessionStorage.getItem(key);
      if (saved) { restore(JSON.parse(saved)); sessionStorage.removeItem(key); }
      show('Current', status.publishedAt);
    } catch (error) {
      if (error.status === 409) show('Updating', 'Publication changed during reconciliation; retrying.');
      else {
        show(error instanceof TypeError || error.name === 'TimeoutError' ? 'Disconnected' : 'Failed', error.message);
        console.error('Standard Display reconciliation failed:', error);
      }
    } finally {
      busy = false;
      if (!stopped) { clearTimeout(timer); timer = setTimeout(() => reconcile(), requested ? 0 : 2500); }
    }
  }
  window.LcmDisplay = { refresh: () => reconcile(true), reconcile: () => reconcile(), capture, restore };
  function start() {
    document.body.appendChild(badge);
    show('Stale', 'Checking published revision');
    reconcile();
  }
  window.addEventListener('focus', () => reconcile());
  window.addEventListener('online', () => reconcile());
  document.addEventListener('visibilitychange', () => { if (!document.hidden) reconcile(); });
  window.addEventListener('keydown', event => {
    if (event.key === 'F5') { event.preventDefault(); event.stopImmediatePropagation(); reconcile(true); }
  }, true);
  window.addEventListener('beforeunload', () => { stopped = true; clearTimeout(timer); });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
