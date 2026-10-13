/**
 * LCM Table Print & PDF Export Atom (LcmTablePrintAtom)
 * Version: 10.0.0
 * Date: 2026-10-13
 * 
 * Modular, zero-dependency Print & PDF Export engine for any HTML table display.
 * Provides live WYSIWYG A4/Letter paper preview with a non-blocking floating toolbar,
 * dynamic margin & density scaling, monochrome ink-saver theme, dynamic contextual
 * metadata header, and cross-dashboard localStorage preference persistence.
 */

(function (root, factory) {
  var instance = factory();
  if (typeof window !== 'undefined') { window.LcmTablePrintAtom = instance; }
  if (typeof globalThis !== 'undefined') { globalThis.LcmTablePrintAtom = instance; }
  if (typeof self !== 'undefined') { self.LcmTablePrintAtom = instance; }
  if (typeof root !== 'undefined') { root.LcmTablePrintAtom = instance; }
  if (typeof module === 'object' && module.exports) { module.exports = instance; }
  if (typeof define === 'function' && define.amd) { define([], function () { return instance; }); }
}(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var STORAGE_KEY = 'lcm_print_prefs';
  var DEFAULT_PREFS = {
    paperSize: 'A4',
    orientation: 'landscape',
    margins: 'small',
    density: 'compact',
    theme: 'color',
    includeHeader: true
  };

  var activeConfig = {
    documentTitle: 'LCM Data Catalog',
    subsystem: 'LCM',
    tableSelector: 'table',
    tbodySelector: 'tbody',
    getViewMode: null,
    getFileName: null,
    getDate: null,
    getFilterSummary: null,
    getViewBadge: null,
    triggerButtonId: null,
    onBeforePrint: null,
    onAfterPrint: null
  };

  function getSavedPrefs() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (raw) return Object.assign({}, DEFAULT_PREFS, JSON.parse(raw));
    } catch (e) { }
    return Object.assign({}, DEFAULT_PREFS);
  }

  function savePrefs(prefs) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
    } catch (e) { }
  }

  function getPrefsFromDOM() {
    var modal = document.getElementById('lcm-print-modal-overlay');
    var toolbar = document.getElementById('lcm-print-preview-toolbar');

    // Check if toolbar is active
    if (document.body.classList.contains('live-preview-mode') && toolbar) {
      var bPaper = document.getElementById('lcm-bar-paper-size');
      var bOrient = document.getElementById('lcm-bar-orientation');
      var bMarg = document.getElementById('lcm-bar-margins');
      var bDense = document.getElementById('lcm-bar-density');
      var bThm = document.getElementById('lcm-bar-theme');
      var pHead = document.getElementById('lcm-print-include-header');
      return {
        paperSize: bPaper ? bPaper.value : DEFAULT_PREFS.paperSize,
        orientation: bOrient ? bOrient.value : DEFAULT_PREFS.orientation,
        margins: bMarg ? bMarg.value : DEFAULT_PREFS.margins,
        density: bDense ? bDense.value : DEFAULT_PREFS.density,
        theme: bThm ? bThm.value : DEFAULT_PREFS.theme,
        includeHeader: pHead ? pHead.checked : DEFAULT_PREFS.includeHeader
      };
    }

    if (modal) {
      var pSize = document.getElementById('lcm-print-paper-size');
      var pOrient2 = document.getElementById('lcm-print-orientation');
      var pMarg2 = document.getElementById('lcm-print-margins');
      var pDense2 = document.getElementById('lcm-print-density');
      var pThm2 = document.getElementById('lcm-print-theme');
      var pHead2 = document.getElementById('lcm-print-include-header');
      return {
        paperSize: pSize ? pSize.value : DEFAULT_PREFS.paperSize,
        orientation: pOrient2 ? pOrient2.value : DEFAULT_PREFS.orientation,
        margins: pMarg2 ? pMarg2.value : DEFAULT_PREFS.margins,
        density: pDense2 ? pDense2.value : DEFAULT_PREFS.density,
        theme: pThm2 ? pThm2.value : DEFAULT_PREFS.theme,
        includeHeader: pHead2 ? pHead2.checked : DEFAULT_PREFS.includeHeader
      };
    }

    return getSavedPrefs();
  }

  function syncControlsWithPrefs(prefs) {
    // Modal Controls
    var pSize = document.getElementById('lcm-print-paper-size');
    var pOrient = document.getElementById('lcm-print-orientation');
    var pMargins = document.getElementById('lcm-print-margins');
    var pDensity = document.getElementById('lcm-print-density');
    var pTheme = document.getElementById('lcm-print-theme');
    var pHeader = document.getElementById('lcm-print-include-header');

    if (pSize) pSize.value = prefs.paperSize;
    if (pOrient) pOrient.value = prefs.orientation;
    if (pMargins) pMargins.value = prefs.margins;
    if (pDensity) pDensity.value = prefs.density;
    if (pTheme) pTheme.value = prefs.theme;
    if (pHeader) pHeader.checked = prefs.includeHeader;

    // Toolbar Controls
    var bSize = document.getElementById('lcm-bar-paper-size');
    var bOrient = document.getElementById('lcm-bar-orientation');
    var bMargins = document.getElementById('lcm-bar-margins');
    var bDensity = document.getElementById('lcm-bar-density');
    var bTheme = document.getElementById('lcm-bar-theme');

    if (bSize) bSize.value = prefs.paperSize;
    if (bOrient) bOrient.value = prefs.orientation;
    if (bMargins) bMargins.value = prefs.margins;
    if (bDensity) bDensity.value = prefs.density;
    if (bTheme) bTheme.value = prefs.theme;
  }

  function applyPrefsToDOM(prefs) {
    var marginVal = '12mm';
    if (prefs.margins === 'small') marginVal = '6mm';
    if (prefs.margins === 'zero') marginVal = '0mm';

    var fontSize = '8pt';
    var cellPadding = '3px 5px';
    if (prefs.density === 'normal') { fontSize = '9.5pt'; cellPadding = '5px 7px'; }
    if (prefs.density === 'comfortable') { fontSize = '11pt'; cellPadding = '8px 10px'; }

    var dynamicStyle = document.getElementById('lcm-dynamic-print-style');
    if (!dynamicStyle) {
      dynamicStyle = document.createElement('style');
      dynamicStyle.id = 'lcm-dynamic-print-style';
      document.head.appendChild(dynamicStyle);
    }

    var monoFilter = (prefs.theme === 'mono') ? '.badge, .tool-ext-badge, th, td { filter: grayscale(100%) !important; }' : '';
    var headerDisp = (!prefs.includeHeader) ? '.print-header, #lcm-print-header-block, #print-header-block { display: none !important; }' : '';

    var dateText = (typeof activeConfig.getDate === 'function')
      ? activeConfig.getDate()
      : new Date().toISOString().replace('T', ' ').substring(0, 19);
    dateText = dateText.replace(/^Generated:\s*/i, '');

    var subsystemText = activeConfig.subsystem || 'LCM';

    var titleText = activeConfig.documentTitle || 'LCM Data Catalog';
    var modeText = (typeof activeConfig.getViewMode === 'function')
      ? activeConfig.getViewMode()
      : ((typeof activeConfig.getViewBadge === 'function') ? activeConfig.getViewBadge() : '');
    modeText = modeText.replace(/^Mode:\s*/i, '');

    var fileNameText = (typeof activeConfig.getFileName === 'function')
      ? activeConfig.getFileName()
      : (window.location.pathname ? window.location.pathname.split('/').pop().split('\\').pop() : 'Catalog.html');
    fileNameText = fileNameText.replace(/^.*[\\\/]/, '');

    dynamicStyle.innerHTML =
      '@media print {' +
      '@page { ' +
      'size: ' + prefs.paperSize + ' ' + prefs.orientation + '; ' +
      'margin: ' + marginVal + '; ' +
      '@top-left { content: "' + titleText.replace(/"/g, '') + '"; font-size: 8pt; font-weight: 700; color: #222; } ' +
      '@top-center { content: "' + modeText.replace(/"/g, '') + '"; font-size: 8pt; font-weight: 700; color: #222; } ' +
      '@top-right { content: "' + fileNameText.replace(/"/g, '') + '"; font-size: 8pt; font-family: monospace; color: #222; } ' +
      '@bottom-left { content: "' + dateText.replace(/"/g, '') + '"; font-size: 8pt; font-family: monospace; color: #444; } ' +
      '@bottom-center { content: "' + subsystemText.replace(/"/g, '') + '"; font-size: 8pt; font-weight: 600; color: #444; } ' +
      '@bottom-right { content: counter(page) " / " counter(pages); font-size: 8pt; font-family: monospace; color: #444; } ' +
      '}' +
      'body { font-size: ' + fontSize + ' !important; background: #fff !important; color: #000 !important; padding: 0 !important; }' +
      activeConfig.tableSelector + ' { width: 100% !important; font-size: ' + fontSize + ' !important; }' +
      'th { padding: ' + cellPadding + ' !important; font-size: ' + fontSize + ' !important; }' +
      'td { padding: ' + cellPadding + ' !important; font-size: ' + fontSize + ' !important; }' +
      monoFilter +
      headerDisp +
      '#lcm-print-preview-toolbar, #lcm-print-modal-overlay { display: none !important; }' +
      '}' +
      'body.live-preview-mode .table-container { font-size: ' + fontSize + ' !important; }' +
      'body.live-preview-mode th, body.live-preview-mode td { padding: ' + cellPadding + ' !important; font-size: ' + fontSize + ' !important; }' +
      (prefs.theme === 'mono' ? 'body.live-preview-mode .badge, body.live-preview-mode .tool-ext-badge, body.live-preview-mode th, body.live-preview-mode td { filter: grayscale(100%) !important; }' : '') +
      (!prefs.includeHeader ? 'body.live-preview-mode .print-header, body.live-preview-mode #lcm-print-header-block, body.live-preview-mode #print-header-block { display: none !important; }' : '');
  }

  function injectModalDOM() {
    if (document.getElementById('lcm-print-modal-overlay')) return;

    var modalHtml =
      '<!-- Print Configuration Modal Dialog -->' +
      '<div class="modal-overlay" id="lcm-print-modal-overlay" style="display: none; position: fixed; top:0; left:0; right:0; bottom:0; background: rgba(0,0,0,0.75); z-index: 9999; justify-content: center; align-items: center; backdrop-filter: blur(4px);">' +
      '<div class="modal-card" id="lcm-print-modal-card" style="background: var(--bg-secondary, #161b22); border: 1px solid var(--border, #30363d); border-radius: 12px; padding: 20px; width: 90%; max-width: 620px; box-shadow: 0 16px 40px rgba(0,0,0,0.5); color: var(--text-primary, #c9d1d9); font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif;">' +
      '<div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border, #30363d); padding-bottom: 12px; margin-bottom: 14px;">' +
      '<div style="font-size: 16px; font-weight: 700; display: flex; align-items: center; gap: 8px; color: var(--text-primary, #f0f6fc);">' +
      '<span>🖨️</span> Print & PDF Export Configuration' +
      '</div>' +
      '<button class="modal-close" id="lcm-btn-close-print-modal" style="background: none; border: none; font-size: 20px; color: var(--text-secondary, #8b949e); cursor: pointer;" title="Close dialog">&times;</button>' +
      '</div>' +
      '<div style="font-size: 12px; color: var(--text-secondary, #8b949e); margin-bottom: 14px;">' +
      'Configure page layout, margins, and density. Click <strong>Live Preview</strong> to inspect the document without obstruction.' +
      '</div>' +
      '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; background: var(--bg-primary, #0d1117); border: 1px solid var(--border, #30363d); border-radius: 8px; padding: 14px;">' +
      '<div>' +
      '<label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary, #8b949e); display: block; margin-bottom: 4px;">Paper Size</label>' +
      '<select id="lcm-print-paper-size" style="width: 100%; background: var(--bg-secondary, #161b22); border: 1px solid var(--border, #30363d); color: var(--text-primary, #c9d1d9); padding: 6px 10px; border-radius: 6px; font-size: 12px;">' +
      '<option value="A4">A4 (210 × 297 mm) - Default</option>' +
      '<option value="Letter">Letter (8.5 × 11 in)</option>' +
      '<option value="Legal">Legal (8.5 × 14 in)</option>' +
      '<option value="A3">A3 (297 × 420 mm) - Large</option>' +
      '</select>' +
      '</div>' +
      '<div>' +
      '<label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary, #8b949e); display: block; margin-bottom: 4px;">Orientation</label>' +
      '<select id="lcm-print-orientation" style="width: 100%; background: var(--bg-secondary, #161b22); border: 1px solid var(--border, #30363d); color: var(--text-primary, #c9d1d9); padding: 6px 10px; border-radius: 6px; font-size: 12px;">' +
      '<option value="landscape">Landscape (Recommended)</option>' +
      '<option value="portrait">Portrait</option>' +
      '</select>' +
      '</div>' +
      '<div>' +
      '<label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary, #8b949e); display: block; margin-bottom: 4px;">Margins (Boundaries)</label>' +
      '<select id="lcm-print-margins" style="width: 100%; background: var(--bg-secondary, #161b22); border: 1px solid var(--border, #30363d); color: var(--text-primary, #c9d1d9); padding: 6px 10px; border-radius: 6px; font-size: 12px;">' +
      '<option value="small">Small (6mm) - Fit More</option>' +
      '<option value="normal">Normal (12mm)</option>' +
      '<option value="zero">Zero Margins (0mm)</option>' +
      '</select>' +
      '</div>' +
      '<div>' +
      '<label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary, #8b949e); display: block; margin-bottom: 4px;">Fit / Sizing Density</label>' +
      '<select id="lcm-print-density" style="width: 100%; background: var(--bg-secondary, #161b22); border: 1px solid var(--border, #30363d); color: var(--text-primary, #c9d1d9); padding: 6px 10px; border-radius: 6px; font-size: 12px;">' +
      '<option value="compact">Fit to Page / Compact (8pt)</option>' +
      '<option value="normal">Standard (9.5pt)</option>' +
      '<option value="comfortable">Comfortable (11pt)</option>' +
      '</select>' +
      '</div>' +
      '<div>' +
      '<label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary, #8b949e); display: block; margin-bottom: 4px;">Color Theme</label>' +
      '<select id="lcm-print-theme" style="width: 100%; background: var(--bg-secondary, #161b22); border: 1px solid var(--border, #30363d); color: var(--text-primary, #c9d1d9); padding: 6px 10px; border-radius: 6px; font-size: 12px;">' +
      '<option value="color">Full Color (Badges & Highlights)</option>' +
      '<option value="mono">Ink-Saver Monochrome (Grayscale)</option>' +
      '</select>' +
      '</div>' +
      '<div>' +
      '<label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-secondary, #8b949e); display: block; margin-bottom: 4px;">Header & Context</label>' +
      '<label style="display: flex; align-items: center; gap: 8px; font-size: 12px; color: var(--text-primary, #c9d1d9); margin-top: 6px; cursor: pointer;">' +
      '<input type="checkbox" id="lcm-print-include-header" checked>' +
      '<span>Include Filter Summary & Date</span>' +
      '</label>' +
      '</div>' +
      '</div>' +
      '<div style="display: flex; justify-content: space-between; align-items: center; margin-top: 18px;">' +
      '<button class="btn-export" id="lcm-btn-start-live-preview" style="background: rgba(56, 139, 253, 0.15); border: 1px solid rgba(56, 139, 253, 0.4); color: #79c0ff; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; display: flex; align-items: center; gap: 6px;">' +
      '<span>👁️</span> Live Preview' +
      '</button>' +
      '<div style="display: flex; gap: 10px;">' +
      '<button class="btn-reset" id="lcm-btn-cancel-print" style="background: transparent; border: 1px solid var(--border, #30363d); color: var(--text-secondary, #8b949e); padding: 8px 16px; border-radius: 6px; cursor: pointer; font-size: 13px;">Cancel</button>' +
      '<button class="btn-action btn-run-action" id="lcm-btn-execute-print" style="background: var(--accent, #58a6ff); color: #fff; border: none; padding: 8px 18px; border-radius: 6px; font-weight: 700; font-size: 13px; cursor: pointer; display: flex; align-items: center; gap: 6px;">' +
      '<span>🖨️</span> Print / Save PDF' +
      '</button>' +
      '</div>' +
      '</div>' +
      '</div>' +
      '</div>' +
      '<!-- Floating Non-Blocking Live Preview Toolbar -->' +
      '<div id="lcm-print-preview-toolbar" style="display: none; position: fixed; top: 0; left: 0; right: 0; height: 50px; background: rgba(22, 27, 34, 0.96); border-bottom: 2px solid #58a6ff; z-index: 10000; box-shadow: 0 4px 20px rgba(0,0,0,0.5); backdrop-filter: blur(8px); justify-content: space-between; align-items: center; padding: 0 18px; font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif; font-size: 13px; color: #f0f6fc;">' +
      '<div style="display: flex; align-items: center; gap: 14px;">' +
      '<div style="display: flex; align-items: center; gap: 6px; font-weight: 700; color: #79c0ff;">' +
      '<span style="font-size: 16px;">📄</span> Document Preview Mode' +
      '</div>' +
      '<div style="display: flex; align-items: center; gap: 8px;">' +
      '<select id="lcm-bar-paper-size" style="background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; padding: 4px 8px; border-radius: 4px; font-size: 12px;">' +
      '<option value="A4">A4</option>' +
      '<option value="Letter">Letter</option>' +
      '<option value="Legal">Legal</option>' +
      '<option value="A3">A3</option>' +
      '</select>' +
      '<select id="lcm-bar-orientation" style="background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; padding: 4px 8px; border-radius: 4px; font-size: 12px;">' +
      '<option value="landscape">Landscape</option>' +
      '<option value="portrait">Portrait</option>' +
      '</select>' +
      '<select id="lcm-bar-margins" style="background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; padding: 4px 8px; border-radius: 4px; font-size: 12px;">' +
      '<option value="small">Marg: Small</option>' +
      '<option value="normal">Marg: Normal</option>' +
      '<option value="zero">Marg: Zero</option>' +
      '</select>' +
      '<select id="lcm-bar-density" style="background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; padding: 4px 8px; border-radius: 4px; font-size: 12px;">' +
      '<option value="compact">Compact (8pt)</option>' +
      '<option value="normal">Standard (9.5pt)</option>' +
      '<option value="comfortable">Comfortable (11pt)</option>' +
      '</select>' +
      '<select id="lcm-bar-theme" style="background: #0d1117; border: 1px solid #30363d; color: #c9d1d9; padding: 4px 8px; border-radius: 4px; font-size: 12px;">' +
      '<option value="color">Color</option>' +
      '<option value="mono">Grayscale</option>' +
      '</select>' +
      '</div>' +
      '</div>' +
      '<div style="display: flex; align-items: center; gap: 10px;">' +
      '<button id="lcm-bar-btn-settings" style="background: #21262d; border: 1px solid #30363d; color: #c9d1d9; padding: 6px 12px; border-radius: 6px; cursor: pointer; font-size: 12px; display: flex; align-items: center; gap: 6px;" title="Open full configuration dialog">' +
      '<span>⚙️</span> Config' +
      '</button>' +
      '<button id="lcm-bar-btn-print" style="background: #238636; color: #fff; border: 1px solid rgba(255,255,255,0.2); padding: 6px 16px; border-radius: 6px; font-weight: 700; font-size: 13px; cursor: pointer; display: flex; align-items: center; gap: 6px;" title="Open browser print dialog">' +
      '<span>🖨️</span> Print / Save PDF' +
      '</button>' +
      '<button id="lcm-bar-btn-exit" style="background: rgba(248, 81, 73, 0.15); border: 1px solid rgba(248, 81, 73, 0.4); color: #ff7b72; padding: 6px 14px; border-radius: 6px; font-weight: 600; cursor: pointer; font-size: 12px; display: flex; align-items: center; gap: 4px;" title="Exit live preview mode (Shortcut: ESC)">' +
      '<span>✕</span> Exit Preview' +
      '</button>' +
      '</div>' +
      '</div>';

    var temp = document.createElement('div');
    temp.innerHTML = modalHtml;
    while (temp.firstChild) {
      document.body.appendChild(temp.firstChild);
    }

    // Bind Modal Events
    var btnClose = document.getElementById('lcm-btn-close-print-modal');
    var btnCancel = document.getElementById('lcm-btn-cancel-print');
    var btnPreview = document.getElementById('lcm-btn-start-live-preview');
    var btnPrint = document.getElementById('lcm-btn-execute-print');

    if (btnClose) btnClose.addEventListener('click', function () { closeModal(); });
    if (btnCancel) btnCancel.addEventListener('click', function () { closeModal(); });
    if (btnPreview) btnPreview.addEventListener('click', function () { enterLivePreview(); });
    if (btnPrint) btnPrint.addEventListener('click', function () { executePrint(); });

    // Bind Toolbar Events
    var barSettings = document.getElementById('lcm-bar-btn-settings');
    var barPrint = document.getElementById('lcm-bar-btn-print');
    var barExit = document.getElementById('lcm-bar-btn-exit');

    if (barSettings) barSettings.addEventListener('click', function () { openModal(); });
    if (barPrint) barPrint.addEventListener('click', function () { executePrint(); });
    if (barExit) barExit.addEventListener('click', function () { exitLivePreview(); });

    // Sync onChange for all input selectors
    var modalInputs = ['lcm-print-paper-size', 'lcm-print-orientation', 'lcm-print-margins', 'lcm-print-density', 'lcm-print-theme', 'lcm-print-include-header'];
    modalInputs.forEach(function (id) {
      var el = document.getElementById(id);
      if (el) {
        el.addEventListener('change', function () {
          var prefs = getPrefsFromDOM();
          savePrefs(prefs);
          syncControlsWithPrefs(prefs);
          applyPrefsToDOM(prefs);
        });
      }
    });

    var barInputs = ['lcm-bar-paper-size', 'lcm-bar-orientation', 'lcm-bar-margins', 'lcm-bar-density', 'lcm-bar-theme'];
    barInputs.forEach(function (id) {
      var el = document.getElementById(id);
      if (el) {
        el.addEventListener('change', function () {
          var prefs = getPrefsFromDOM();
          savePrefs(prefs);
          syncControlsWithPrefs(prefs);
          applyPrefsToDOM(prefs);
        });
      }
    });

    var overlay = document.getElementById('lcm-print-modal-overlay');
    if (overlay) {
      overlay.addEventListener('click', function (e) {
        if (e.target.id === 'lcm-print-modal-overlay') closeModal();
      });
    }

    // Global ESC handler
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        if (document.body.classList.contains('live-preview-mode')) {
          exitLivePreview();
        } else {
          closeModal();
        }
      }
    });
  }

  function injectLivePreviewStyles() {
    if (document.getElementById('lcm-live-preview-style')) return;
    var style = document.createElement('style');
    style.id = 'lcm-live-preview-style';
    style.innerHTML =
      'body.live-preview-mode {' +
      'background: #2b2e35 !important;' +
      'padding-top: 65px !important;' +
      'padding-bottom: 50px !important;' +
      '}' +
      'body.live-preview-mode .table-container {' +
      'max-width: 1200px !important;' +
      'margin: 0 auto !important;' +
      'background: #ffffff !important;' +
      'color: #111111 !important;' +
      'box-shadow: 0 12px 36px rgba(0,0,0,0.5) !important;' +
      'border-radius: 4px !important;' +
      'border: 1px solid #c8c8c8 !important;' +
      'padding: 28px 36px !important;' +
      'max-height: none !important;' +
      'overflow: visible !important;' +
      'position: relative !important;' +
      '}' +
      'body.live-preview-mode table,' +
      'body.live-preview-mode .scrollable-table {' +
      'width: 100% !important;' +
      'background: #ffffff !important;' +
      'color: #111111 !important;' +
      '}' +
      'body.live-preview-mode thead {' +
      'position: static !important;' +
      'background: #f0f2f5 !important;' +
      '}' +
      'body.live-preview-mode th {' +
      'background: #f0f2f5 !important;' +
      'color: #111111 !important;' +
      'border-color: #d0d0d0 !important;' +
      'position: static !important;' +
      '}' +
      'body.live-preview-mode th::after {' +
      'content: none !important;' +
      '}' +
      'body.live-preview-mode td {' +
      'background: #ffffff !important;' +
      'color: #222222 !important;' +
      'border-color: #e5e5e5 !important;' +
      '}' +
      'body.live-preview-mode tr:hover td {' +
      'background: #fafafa !important;' +
      '}' +
      'body.live-preview-mode .print-header,' +
      'body.live-preview-mode #lcm-print-header-block,' +
      'body.live-preview-mode #print-header-block {' +
      'display: block !important;' +
      'margin-bottom: 16px !important;' +
      '}' +
      'body.live-preview-mode header,' +
      'body.live-preview-mode .header,' +
      'body.live-preview-mode .header-title,' +
      'body.live-preview-mode .top-nav,' +
      'body.live-preview-mode .metrics-grid,' +
      'body.live-preview-mode .tabs,' +
      'body.live-preview-mode .filter-panel-top,' +
      'body.live-preview-mode .search-bar,' +
      'body.live-preview-mode .col-filter-row,' +
      'body.live-preview-mode .action-btns,' +
      'body.live-preview-mode th:last-child,' +
      'body.live-preview-mode td:last-child {' +
      'display: none !important;' +
      '}';
    document.head.appendChild(style);
  }

  function updateHeaderMetadata() {
    var header = document.getElementById('lcm-print-header-block') ||
      document.getElementById('print-header-block') ||
      document.querySelector('.print-header');
    var footer = document.getElementById('lcm-print-footer-block') ||
      document.getElementById('print-footer-block') ||
      document.querySelector('.print-footer');

    var rows = document.querySelectorAll((activeConfig.tbodySelector || 'tbody') + ' tr');
    var visibleRows = Array.from(rows).filter(function (r) { return r.style.display !== 'none'; }).length;

    var titleText = activeConfig.documentTitle || 'LCM Data Catalog';
    var modeText = (typeof activeConfig.getViewMode === 'function')
      ? activeConfig.getViewMode()
      : ((typeof activeConfig.getViewBadge === 'function') ? activeConfig.getViewBadge() : ('All Items (' + visibleRows + ')'));
    modeText = modeText.replace(/^Mode:\s*/i, '');

    var fileNameText = (typeof activeConfig.getFileName === 'function')
      ? activeConfig.getFileName()
      : (window.location.pathname ? window.location.pathname.split('/').pop().split('\\').pop() : 'Catalog.html');
    fileNameText = fileNameText.replace(/^.*[\\\/]/, '');

    var dateText = (typeof activeConfig.getDate === 'function')
      ? activeConfig.getDate()
      : new Date().toISOString().replace('T', ' ').substring(0, 19);
    dateText = dateText.replace(/^Generated:\s*/i, '');

    var subsystemText = activeConfig.subsystem || 'LCM';

    var tableContainer = document.querySelector('.table-container') || document.querySelector(activeConfig.tableSelector);

    if (!header) {
      header = document.createElement('div');
      header.className = 'print-header';
      header.id = 'lcm-print-header-block';
      header.innerHTML =
        '<div style="display: grid; grid-template-columns: 1fr auto 1fr; align-items: baseline; border-bottom: 2px solid #222; padding-bottom: 5px; margin-bottom: 6px;">' +
        '<div style="font-size: 13pt; font-weight: 800; color: #000;" id="lcm-print-header-title"></div>' +
        '<div style="font-size: 10pt; font-weight: 700; color: #333; text-align: center;" id="lcm-print-header-mode"></div>' +
        '<div style="font-size: 8.5pt; font-family: monospace; color: #444; text-align: right;" id="lcm-print-header-file"></div>' +
        '</div>';
      if (tableContainer && tableContainer.parentNode) {
        tableContainer.parentNode.insertBefore(header, tableContainer);
      } else if (document.body) {
        document.body.insertBefore(header, document.body.firstChild);
      }
    }

    if (!footer) {
      footer = document.createElement('div');
      footer.className = 'print-footer';
      footer.id = 'lcm-print-footer-block';
      footer.innerHTML =
        '<div style="display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; border-top: 1px solid #666; padding-top: 4px; margin-top: 8px; font-size: 8pt; color: #444;">' +
        '<div style="text-align: left;" id="lcm-print-footer-date"></div>' +
        '<div style="text-align: center; font-weight: 600;" id="lcm-print-footer-subsystem"></div>' +
        '<div style="text-align: right; font-family: monospace; font-weight: 600;" id="lcm-print-footer-page">1 / 1</div>' +
        '</div>';
      if (tableContainer && tableContainer.nextSibling) {
        tableContainer.parentNode.insertBefore(footer, tableContainer.nextSibling);
      } else if (tableContainer) {
        tableContainer.parentNode.appendChild(footer);
      } else if (document.body) {
        document.body.appendChild(footer);
      }
    }

    var titleEl = header.querySelector('#print-header-title') || header.querySelector('#lcm-print-header-title') || header.querySelector('h1');
    var modeEl = header.querySelector('#print-header-mode') || header.querySelector('#lcm-print-header-mode') || header.querySelector('#print-view-badge') || header.querySelector('#lcm-print-view-badge');
    var fileEl = header.querySelector('#print-header-file') || header.querySelector('#lcm-print-header-file');
    var filterEl = header.querySelector('#lcm-print-filter-summary') || header.querySelector('#print-filter-summary');

    if (titleEl) titleEl.innerText = titleText;
    if (modeEl) modeEl.innerText = modeText;
    if (fileEl) fileEl.innerText = fileNameText;
    if (filterEl) {
      var filterText = (typeof activeConfig.getFilterSummary === 'function') ? activeConfig.getFilterSummary() : 'All Items';
      filterEl.innerText = 'Filter: ' + filterText;
    }

    var dateEl = footer.querySelector('#print-footer-date') || footer.querySelector('#lcm-print-footer-date');
    var subEl = footer.querySelector('#print-footer-subsystem') || footer.querySelector('#lcm-print-footer-subsystem');
    var pageEl = footer.querySelector('#print-footer-page') || footer.querySelector('#lcm-print-footer-page');

    if (dateEl) dateEl.innerText = dateText;
    if (subEl) subEl.innerText = subsystemText;
    if (pageEl) pageEl.innerText = '1 / 1';
  }

  function notifyDaemon(action, prefs) {
    try {
      var payload = {
        documentTitle: activeConfig.documentTitle || document.title,
        subsystem: activeConfig.subsystem || 'LCM',
        viewMode: (typeof activeConfig.getViewMode === 'function') ? activeConfig.getViewMode() : '',
        action: action || 'preview',
        prefs: prefs || getSavedPrefs()
      };
      var url = 'http://127.0.0.1:9876/print';
      if (typeof fetch === 'function') {
        fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        }).catch(function () { });
      }
    } catch (e) { }
  }

  function openModal() {
    injectModalDOM();
    var prefs = getSavedPrefs();
    syncControlsWithPrefs(prefs);
    applyPrefsToDOM(prefs);

    var modal = document.getElementById('lcm-print-modal-overlay');
    if (modal) modal.style.display = 'flex';
    notifyDaemon('open_preview', prefs);
  }

  function closeModal() {
    var modal = document.getElementById('lcm-print-modal-overlay');
    if (modal) modal.style.display = 'none';
  }

  function enterLivePreview() {
    closeModal();
    injectLivePreviewStyles();
    document.body.classList.add('live-preview-mode');

    var toolbar = document.getElementById('lcm-print-preview-toolbar');
    if (toolbar) toolbar.style.display = 'flex';

    var prefs = getSavedPrefs();
    syncControlsWithPrefs(prefs);
    applyPrefsToDOM(prefs);
    updateHeaderMetadata();
    notifyDaemon('live_preview', prefs);

    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function exitLivePreview() {
    document.body.classList.remove('live-preview-mode');
    var toolbar = document.getElementById('lcm-print-preview-toolbar');
    if (toolbar) toolbar.style.display = 'none';
    closeModal();
  }

  function toggleLivePreview() {
    if (document.body.classList.contains('live-preview-mode')) {
      exitLivePreview();
    } else {
      enterLivePreview();
    }
  }

  function executePrint() {
    var prefs = getPrefsFromDOM();
    savePrefs(prefs);
    syncControlsWithPrefs(prefs);
    applyPrefsToDOM(prefs);
    updateHeaderMetadata();
    closeModal();
    notifyDaemon('print', prefs);

    if (typeof activeConfig.onBeforePrint === 'function') {
      activeConfig.onBeforePrint();
    }

    setTimeout(function () {
      window.print();
      if (typeof activeConfig.onAfterPrint === 'function') {
        activeConfig.onAfterPrint();
      }
    }, 250);
  }

  function init(options) {
    activeConfig = Object.assign({}, activeConfig, options || {});
    injectModalDOM();
    injectLivePreviewStyles();

    var initialPrefs = getSavedPrefs();
    syncControlsWithPrefs(initialPrefs);
    applyPrefsToDOM(initialPrefs);

    if (activeConfig.triggerButtonId) {
      var btn = document.getElementById(activeConfig.triggerButtonId);
      if (btn) {
        btn.addEventListener('click', function (e) {
          e.preventDefault();
          openModal();
        });
      }
    }
  }

  return {
    init: init,
    openModal: openModal,
    openPrintPreview: openModal,
    closeModal: closeModal,
    enterLivePreview: enterLivePreview,
    exitLivePreview: exitLivePreview,
    toggleLivePreview: toggleLivePreview,
    executePrint: executePrint,
    getPrefs: getSavedPrefs,
    savePrefs: savePrefs,
    applyPrefs: applyPrefsToDOM
  };
}));

