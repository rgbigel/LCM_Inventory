/* Authors: Rolf, Copilot. Version: 10.0.1. Date: 2026-10-21. */
'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '..', 'assets', 'lcm-display-freshness.js'), 'utf8');

function harness({ snapshot = false, port = '9876', initialPresentation = '' } = {}) {
  const badges = [];
  const storage = new Map();
  const fields = [{ id: 'search', value: 'operator filter', type: 'text', checked: false, tagName: 'INPUT' }];
  const events = {};
  const state = {
    status: { state: 'Current', revision: 'd1.p1', dataRevision: 'd1', presentationRevision: 'p1', publishedAt: 'now' },
    payload: { tools: [{ Name: 'Example.ps1' }] },
    contentRevision: null, dataStatus: 200, applied: [], reloads: 0, calls: [], timers: [], offline: false
  };
  const document = {
    readyState: 'complete', hidden: false,
    querySelector: selector => selector.includes('lcm-presentation-revision') ?
      { content: initialPresentation } : (snapshot ? null : { content: 'tools' }),
    querySelectorAll: () => fields,
    createElement: () => ({ style: {}, dataset: {}, setAttribute() {} }),
    getElementById: id => fields.find(field => field.id === id),
    body: { appendChild: badge => badges.push(badge) },
    addEventListener: (name, handler) => { events[name] = handler; }
  };
  const context = {
    document, location: { protocol: 'http:', hostname: '127.0.0.1', port, reload: () => state.reloads++ },
    sessionStorage: { getItem: key => storage.get(key), setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) },
    scrollX: 0, scrollY: 42, AbortSignal, TypeError,
    console: { error() {} },
    setTimeout: callback => { state.timers.push(callback); return state.timers.length; },
    clearTimeout() {},
    fetch: async (url, options) => {
      state.calls.push({ url, method: options.method });
      if (state.offline) throw new TypeError('daemon offline');
      const data = url.includes('/data/') ? state.payload : state.status;
      return {
        ok: !url.includes('/data/') || state.dataStatus === 200, status: url.includes('/data/') ? state.dataStatus : 200,
        json: async () => data, text: async () => JSON.stringify(data),
        headers: { get: () => state.contentRevision || state.status.revision }
      };
    },
    addEventListener: (name, handler) => { events[name] = handler; },
    scrollTo() {},
    LcmDisplayApply: async (html, status) => state.applied.push({ html, revision: status.revision }),
    LcmDisplayCaptureState: () => ({ selected: [304], mode: 'source' })
  };
  context.window = context;
  vm.createContext(context);
  vm.runInContext(source, context);
  return { context, state, badges, storage, fields, events };
}
const settled = () => new Promise(resolve => setImmediate(resolve));

test('initial publication applies data and marks its verified revision Current', async () => {
  const h = harness();
  await settled();
  assert.equal(h.badges[0].dataset.state, 'Current');
  assert.equal(h.state.applied.length, 1);
  assert.match(h.state.applied[0].html, /Example\.ps1/);
  assert.equal(h.state.reloads, 0);
  assert.ok(h.state.calls.every(call => call.url.startsWith('/displays/')));
});

test('presentation changed after initial HTML delivery reloads before applying mismatched data', async () => {
  const h = harness({ initialPresentation: 'p0' });
  await settled();
  assert.equal(h.state.reloads, 1);
  assert.equal(h.state.applied.length, 0);
});

test('publication becoming Updating between status and data cannot be marked Current', async () => {
  const h = harness();
  await settled();
  h.state.status = { ...h.state.status, revision: 'd2.p1', dataRevision: 'd2' };
  h.state.dataStatus = 409;
  await h.context.LcmDisplay.reconcile();
  assert.equal(h.state.applied.length, 1);
  assert.equal(h.badges[0].dataset.state, 'Updating');
});

test('data-only revisions apply in place without resetting operator filters', async () => {
  const h = harness();
  await settled();
  h.state.status = { ...h.state.status, revision: 'd2.p1', dataRevision: 'd2' };
  await h.context.LcmDisplay.reconcile();
  assert.equal(h.state.applied.length, 2);
  assert.equal(h.state.reloads, 0);
  assert.equal(h.fields[0].value, 'operator filter');
});

test('presentation transitions save selection and view state before HTTP reload', async () => {
  const h = harness();
  await settled();
  h.state.status = { ...h.state.status, revision: 'd1.p2', presentationRevision: 'p2' };
  await h.context.LcmDisplay.reconcile();
  assert.equal(h.state.reloads, 1);
  const saved = JSON.parse(h.storage.get('lcm-display-view:tools'));
  assert.equal(saved.fields.search.value, 'operator filter');
  assert.deepEqual(saved.custom.selected, [304]);
  assert.equal(saved.custom.mode, 'source');
});

test('dispatch or Updating never means Current and explicit Refresh uses POST', async () => {
  const h = harness();
  await settled();
  h.state.status = { ...h.state.status, state: 'Updating' };
  await h.context.LcmDisplay.refresh();
  assert.equal(h.badges[0].dataset.state, 'Updating');
  assert.equal(h.state.applied.length, 1);
  assert.ok(h.state.calls.some(call => call.url === '/displays/refresh/tools' && call.method === 'POST'));
});

test('lost connection shows Disconnected while retaining the previous applied view', async () => {
  const h = harness();
  await settled();
  h.state.offline = true;
  await h.context.LcmDisplay.reconcile();
  assert.equal(h.badges[0].dataset.state, 'Disconnected');
  assert.equal(h.state.applied.length, 1);
  h.state.offline = false;
  h.state.status = { ...h.state.status, revision: 'd2.p1', dataRevision: 'd2' };
  await h.context.LcmDisplay.reconcile();
  assert.equal(h.badges[0].dataset.state, 'Current');
  assert.equal(h.state.applied.length, 2);
});

test('a publication race cannot apply bytes under another revision identity', async () => {
  const h = harness();
  await settled();
  h.state.status = { ...h.state.status, revision: 'd2.p1', dataRevision: 'd2' };
  h.state.contentRevision = 'd3.p1';
  await h.context.LcmDisplay.reconcile();
  assert.equal(h.state.applied.length, 1);
  assert.equal(h.badges[0].dataset.state, 'Updating');
});

test('untrusted JSON text cannot terminate the adapter payload script element', async () => {
  const h = harness();
  await settled();
  h.state.status = { ...h.state.status, revision: 'd2.p1', dataRevision: 'd2' };
  h.state.payload = { text: '</script><script>alert(1)</script>' };
  await h.context.LcmDisplay.reconcile();
  const html = h.state.applied[1].html;
  assert.equal((html.match(/<\/script>/g) || []).length, 1);
  assert.match(html, /\\u003c\/script>/);
});

test('alternate-port delivery fails without attempting any data request', async () => {
  const h = harness({ port: '9999' });
  await settled();
  assert.equal(h.badges[0].dataset.state, 'Failed');
  assert.equal(h.state.calls.length, 0);
  assert.equal(h.state.timers.length, 0);
});

test('historical snapshots have no live reconciliation or automatic evidence execution', async () => {
  const h = harness({ snapshot: true });
  await settled();
  assert.equal(h.context.LcmDisplay, undefined);
  assert.equal(h.state.calls.length, 0);
  assert.equal(h.badges.length, 0);
});
