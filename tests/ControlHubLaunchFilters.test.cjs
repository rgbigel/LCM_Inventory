// Purpose: Verify Standard Display launch filters and reconciliation state.
// Authors: Rolf, Copilot
// Date: 2026-10-21
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assets = path.join(__dirname, '..', 'assets');
const hub = fs.readFileSync(path.join(assets, 'CM_CONTROL_HUB.html'), 'utf8');
const dates = fs.readFileSync(path.join(assets, 'CM_CRP_DATES_READONLY.html'), 'utf8');
const helpers = hub.slice(hub.indexOf('    function readLaunchFilters('), hub.indexOf('    function evaluateProposalMatch('));
test('cohort wizard selects the cohort and opens actions through the defined deferred helper', () => {
  const selected = [];
  const opened = [];
  const frames = [];
  let stopped = false;
  const context = vm.createContext({
    selectItemTarget: target => selected.push(target),
    showDropdownById: id => opened.push(id),
    requestAnimationFrame: callback => frames.push(callback)
  });
  vm.runInContext(hub.slice(hub.indexOf('    function selectCohortAndOpenActions('),
    hub.indexOf('    function manageCohortState(')), context);
  vm.runInContext(hub.slice(hub.indexOf('    function deferShowDropdown('),
    hub.indexOf('    function toggleShowDropdownById(')), context);
  context.selectCohortAndOpenActions({ stopPropagation: () => { stopped = true; } }, 'COH-282');
  assert.equal(stopped, true);
  assert.deepEqual(selected, ['COH:COH-282']);
  assert.deepEqual(opened, []);
  frames.shift()();
  assert.deepEqual(opened, []);
  frames.shift()();
  assert.deepEqual(opened, ['cohort-COH-282']);
});
function hubContext() {
  const elements = { scopeSelect: { value: 'LCM_AI', options: [{ value: 'LCM_AI' }] } };
  const context = vm.createContext({
    URLSearchParams, window: {}, launchFilters: {}, selectedIds: new Set([1]),
    activeItemTarget: 'CRP:1', activeRailFilter: 'review', activeSort: 'id-desc',
    proposalsData: { proposals: [{ id: 1 }] }, docsCache: {}, reviewReceipts: [], activeLog: '',
    $: key => elements[key] || null,
    DOMParser: class { parseFromString(html) { return { querySelector: () => ({ textContent: html }) }; } }
  });
  vm.runInContext(helpers, context);
  for (const name of ['populateScopeFilter', 'populateCohortFilter', 'populateItemTargets',
    'reconcileActiveItemTarget', 'calculateStatusCounts', 'renderTable', 'renderSelectionPanel',
    'renderReviewCohortPreview', 'renderSelectedItemLifecycle', 'renderDatesTable']) context[name] = () => {};
  vm.runInContext(hub.slice(hub.indexOf('    window.LcmDisplayApply ='), hub.lastIndexOf('  </script>')), context);
  return context;
}
test('Hub matches every supported lifecycle state exactly, including held and closed states', () => {
  const context = hubContext();
  for (const state of ['suggested', 'in_progress', 'verified', 'in_review', 'completed',
    'pushed', 'held', 'withdrawn', 'rejected', 'superseded']) {
    context.launchFilters = context.readLaunchFilters(new URLSearchParams({ State: state }));
    assert.equal(context.proposalMatchesLaunchFilters({ id: 1, state }), true, state);
    assert.equal(context.proposalMatchesLaunchFilters({ id: 1, state: 'different' }), false, state);
  }
});
test('Hub requires StateEvent dates and matches IDs exactly with CRP/BUG prefixes', () => {
  const context = hubContext();
  for (const event of ['created', 'in_progress', 'completed', 'pushed', 'deferred']) {
    context.launchFilters = context.readLaunchFilters(new URLSearchParams({ StateEvent: event, Id: '1,CRP-002, BUG-3' }));
    assert.equal(context.proposalMatchesLaunchFilters({ id: 2, dates: { [event]: '2026-10-21' } }), true);
    for (const value of [undefined, '', '-', '—']) {
      assert.equal(context.proposalMatchesLaunchFilters({ id: 2, dates: { [event]: value } }), false);
    }
    assert.equal(context.proposalMatchesLaunchFilters({ id: 21, dates: { [event]: '2026-10-21' } }), false);
  }
  for (const [event, field] of [['created', 'timestamp'], ['pushed', 'pushed_at']]) {
    context.launchFilters = context.readLaunchFilters(new URLSearchParams({ StateEvent: event }));
    assert.equal(context.proposalMatchesLaunchFilters({ id: 1, [field]: '2026-10-21' }), true);
  }
});
test('Hub publication and presentation restore retain repo, review mode, state/event and selection', async () => {
  const context = hubContext();
  context.launchFilters = context.readLaunchFilters(new URLSearchParams({ State: 'verified', StateEvent: 'completed', Id: '1,2' }));
  const before = JSON.stringify(context.window.LcmDisplayCaptureState());
  await context.window.LcmDisplayApply(JSON.stringify({ proposals: { proposals: [{ id: 1 }, { id: 2 }] } }));
  assert.equal(JSON.stringify(context.window.LcmDisplayCaptureState()), before);
  const saved = context.window.LcmDisplayCaptureState();
  context.launchFilters = { state: '', event: '', ids: [] };
  context.activeRailFilter = 'all';
  context.$('scopeSelect').value = '';
  context.selectedIds.clear();
  context.window.LcmDisplayRestoreState(saved);
  assert.equal(JSON.stringify(context.window.LcmDisplayCaptureState()), before);
});
function datesContext() {
  const elements = new Map();
  const element = key => {
    if (!elements.has(key)) elements.set(key, { value: '', classList: { contains: () => false }, textContent: '' });
    return elements.get(key);
  };
  element('lcm-display-data').textContent = JSON.stringify({ proposals: { proposals: [] } });
  const context = vm.createContext({
    window: {}, location: { search: '?ReviewMode=true' }, URLSearchParams,
    document: { getElementById: element, addEventListener: () => {} },
    DOMParser: class { parseFromString(html) { return { querySelector: () => ({ textContent: html }) }; } }
  });
  vm.runInContext(dates.match(/<script>\s*("use strict";[\s\S]*?)<\/script>/)[1], context);
  for (const key of ['LcmDisplayApply', 'LcmDisplayCaptureState', 'LcmDisplayRestoreState']) {
    assert.equal(typeof context.window[key], 'function', `Dates ${key} must register before DOMContentLoaded`);
  }
  vm.runInContext('render = () => {};', context);
  return context;
}
test('Dates comma-separated IDs are exact, not substring matches', () => {
  const context = datesContext();
  for (const id of [1, 2, 33]) assert.equal(context.matchesIds({ id }, '1,CRP-002, BUG-33'), true);
  for (const id of [3, 11, 21, 333]) assert.equal(context.matchesIds({ id }, '1,CRP-002, BUG-33'), false);
  assert.equal(context.matchesIds({ id: 1 }, ''), true);
  assert.equal(context.matchesIds({ id: 1 }, 'invalid'), false);
});
test('Dates combines exact IDs, repo, lifecycle state, event and review mode', () => {
  const context = datesContext();
  vm.runInContext(`ledger={proposals:[
    {id:1,origin_repo:"LCM_AI",state:"verified",title:"One",dates:{completed:"2026-10-21"}},
    {id:11,origin_repo:"LCM_AI",state:"verified",title:"Eleven",dates:{completed:"2026-10-21"}},
    {id:2,origin_repo:"LCM_AI",state:"held",title:"Held",dates:{completed:"2026-10-21"}},
    {id:3,origin_repo:"Other",state:"verified",title:"Other",dates:{completed:"2026-10-21"}},
    {id:4,origin_repo:"LCM_AI",state:"verified",title:"Missing",dates:{completed:"-"}}
  ]};`, context);
  for (const [key, value] of Object.entries({ repo: 'LCM_AI', state: 'verified', event: 'completed', fid: '1,2,3,4' })) {
    context.document.getElementById(key).value = value;
  }
  assert.deepEqual(Array.from(context.filtered(), p => p.id), [1]);
  context.document.getElementById('state').value = '';
  assert.deepEqual(Array.from(context.filtered(), p => p.id), [1]);
  vm.runInContext('reviewMode=false;', context);
  assert.deepEqual(Array.from(context.filtered(), p => p.id), [2, 1]);
});
test('Dates publication and restore retain repo, state, event, IDs and review mode', async () => {
  const context = datesContext();
  for (const [key, value] of Object.entries({ repo: 'LCM_AI', state: 'verified', event: 'completed', fid: '1,2' })) {
    context.document.getElementById(key).value = value;
  }
  const saved = context.window.LcmDisplayCaptureState();
  await context.window.LcmDisplayApply(JSON.stringify({ proposals: { proposals: [{ id: 1 }] } }));
  assert.equal(JSON.stringify(context.window.LcmDisplayCaptureState()), JSON.stringify(saved));
  for (const key of ['repo', 'state', 'event', 'fid']) context.document.getElementById(key).value = '';
  vm.runInContext('reviewMode = false;', context);
  context.window.LcmDisplayRestoreState(saved);
  assert.equal(JSON.stringify(context.window.LcmDisplayCaptureState()), JSON.stringify(saved));
});
test('Inventory registers adapters at script evaluation before any documentation modal opens', async () => {
  const html = fs.readFileSync(path.join(assets, 'WORKSPACE_INVENTORY_VIEWER.html'), 'utf8');
  const elements = new Map();
  const listeners = [];
  function element(key) {
    if (!elements.has(key)) {
      const node = { value: '', innerText: '', style: {}, children: [],
        classList: { add() {}, remove() {} }, appendChild(child) { this.children.push(child); } };
      Object.defineProperty(node, 'innerHTML', { set(value) { this.html = value; this.children = []; }, get() { return this.html; } });
      elements.set(key, node);
    }
    return elements.get(key);
  }
  element('lcm-display-data').textContent = JSON.stringify({ inventory: { repositories: [] }, docs: {} });
  const context = vm.createContext({
    window: { addEventListener() {} },
    document: { getElementById: element, createElement: () => ({}), querySelectorAll: () => [],
      addEventListener: (event, callback) => listeners.push([event, callback]) },
    DOMParser: class { parseFromString(text) { return { querySelector: () => ({ textContent: text }) }; } }
  });
  const source = html.match(/<script>\s*(const inventoryPayload[\s\S]*?)<\/script>/)[1];
  vm.runInContext(source, context);
  for (const key of ['LcmDisplayApply', 'LcmDisplayCaptureState', 'LcmDisplayRestoreState']) {
    assert.equal(typeof context.window[key], 'function', `${key} must exist before DOMContentLoaded or modal interactions`);
  }
  for (const [event, callback] of listeners) if (event === 'DOMContentLoaded') callback();
  context.setCategoryFilter('governed');
  element('filterInput').value = 'Fixture';
  const snapshot = context.window.LcmDisplayCaptureState();
  await context.window.LcmDisplayApply(JSON.stringify({
    inventory: { repositories: [
      { RepositoryName: 'Fixture', LCMStatus: 'governed', GitStatus: 'Git', Path: 'D:\\Fixture' },
      { RepositoryName: 'Other', LCMStatus: 'governed', GitStatus: 'Git', Path: 'D:\\Other' }
    ] }, docs: { 'Fixture/README.md': 'Published documentation' }
  }));
  assert.equal(element('valTotal').innerText, 2);
  assert.equal(element('inventoryTableBody').children.length, 1);
  assert.match(element('inventoryTableBody').children[0].innerHTML, /Fixture/);
  assert.equal(element('filterInput').value, 'Fixture');
  assert.equal(JSON.stringify(context.window.LcmDisplayCaptureState()), JSON.stringify(snapshot));
  assert.equal(vm.runInContext('DOCS_CACHE["Fixture/README.md"]', context), 'Published documentation');
  context.setCategoryFilter('ALL');
  context.window.LcmDisplayRestoreState(snapshot);
  assert.equal(context.window.LcmDisplayCaptureState().category, 'governed');
  await assert.rejects(context.window.LcmDisplayApply('{"inventory":{}}'), /malformed/);
});
