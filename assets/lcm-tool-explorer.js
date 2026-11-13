/**
 * LCM Tool Explorer Client Application (10.0.1)
 * Date: 2026-11-08 15:30:00
 * Modern dashboard controller supporting:
 * - Switched Short-Names default column with source-file toggle mode
 * - Unified 8-mode action dropdown (Run, Help, Run with parms, Code editor, Rename, Archive, Delete, Cleanup)
 * - Multi-choice Cleanup modal with live daemon artifact size queries
 * - Dual-field Rename modal (Source filename + Short-Name alias)
 * - Granular Command Alias management with active tag removal and creation
 * - Bulk Column Assignment and Pattern Replacement
 * - Internal Audience visibility toggle
 * - AST dependency visualization
 * - Multi-tab sessionStorage isolation & broadcast sync
 * - Unified Action Intent & Execution Feedback Drawer (CRP-309 WP4)
 */

(function(window, document) {
    'use strict';

    const dataElement = document.getElementById('lcm-display-data');
    let initialPayload = {};
    try {
        initialPayload = dataElement ? JSON.parse(dataElement.textContent) : {};
    } catch (error) {
        console.error('Invalid tool catalog display payload.', error);
    }
    let baselineData = Array.isArray(initialPayload.tools) ? initialPayload.tools : [];
    const requestedDisplayParams = new URLSearchParams(window.location.search);
    window.__LCM_CONFIG__ = Object.assign({}, initialPayload.config || {});
    ['Audience', 'Group', 'Subsystem', 'Role', 'Tool', 'Env', 'Filter'].forEach(key => {
        if (requestedDisplayParams.has(key)) {
            window.__LCM_CONFIG__[key] = requestedDisplayParams.get(key).slice(0, 300);
        }
    });
    if (requestedDisplayParams.has('Subsystem') && !requestedDisplayParams.has('Group')) {
        window.__LCM_CONFIG__.Group = window.__LCM_CONFIG__.Subsystem;
    }
    window.__LCM_OPTIONS__ = initialPayload.options || {};
    let toolsData = JSON.parse(JSON.stringify(baselineData));
    let activeRunningTool = null;
    let activeModalTool = null;
    let activeEditCell = null;
    let activeMenuTool = null;
    let activeCleanupTool = null;
    let activeRenameTool = null;
    let modalAliases = [];
    let isFilteringInternal = false;
    let isShowToolsButtonOn = false;
    let isManualShowToolsFilter = false;
    let currentFilteredTools = [];

    const DAEMON_URL = 'http://127.0.0.1:9876';

    let allShortNamesMap = {};

    function escapeHtml(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    async function loadAllShortNames() {
        try {
            const resp = await fetch(DAEMON_URL + '/query_all_short_names', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
            if (resp.ok) {
                const data = await resp.json();
                if (data && data.map) {
                    allShortNamesMap = data.map;
                    if (isSourceMode) {
                        applyFilters();
                    }
                }
            }
        } catch(e) {
            console.debug('Daemon query_all_short_names unavailable, falling back to catalog data:', e);
        }
    }

    function getShortNamesForTool(t) {
        const set = new Set();
        const leaf = t.Name.split(/[/\\]/).pop();
        const fromMap = (allShortNamesMap && (allShortNamesMap[t.Name] || allShortNamesMap[leaf])) || null;
        if (fromMap && fromMap.length > 0) {
            fromMap.forEach(sn => set.add(sn));
            return Array.from(set);
        }
        // Fallback when daemon map is not populated:
        if (t.ShortName) set.add(t.ShortName);
        if (Array.isArray(t.Aliases)) {
            t.Aliases.forEach(a => { if (a) set.add(a); });
        }
        if (set.size === 0) {
            set.add(leaf.replace(/\.[^/.]+$/, ""));
        }
        return Array.from(set);
    }

    function resolveToolExecutionCommand(tool, preferScriptPath = false) {
        if (!tool) return '';
        const shortNames = getShortNamesForTool(tool);
        // If in short-name mode and valid active launcher exists, use it
        if (!preferScriptPath && shortNames.length > 0) {
            let cand = tool.ShortName;
            if (cand && shortNames.includes(cand)) {
                return cand;
            }
            if (tool.Example && shortNames.includes(tool.Example.trim())) {
                return tool.Example.trim();
            }
            return shortNames[0];
        }
        // Direct invocation via RelativePath or Name (guarantees execution for long names)
        const rel = tool.RelativePath || tool.Name;
        const lower = tool.Name.toLowerCase();
        if (lower.endsWith('.ps1')) return 'pwsh -File "' + rel + '"';
        if (lower.endsWith('.py')) return 'python "' + rel + '"';
        if (lower.endsWith('.cmd') || lower.endsWith('.bat')) return 'cmd /c "' + rel + '"';
        return 'pwsh -File "' + rel + '"';
    }

    // Multi-Tab Coordination & Global Overrides Sync
    const syncChannel = (typeof BroadcastChannel !== 'undefined') ? new BroadcastChannel('lcm_tools_explorer_sync') : null;
    if (syncChannel) {
        syncChannel.onmessage = (event) => {
            if (!event.data) return;
            if (event.data.type === 'CATALOG_UPDATED') {
                showToast('🔄 Tool catalog updated in another tab.');
                applyOverridesFromStorage();
                applyFilters();
            }
        };
    }

    window.addEventListener('storage', (e) => {
        if (e.key === 'lcm_tools_overrides') {
            applyOverridesFromStorage();
            applyFilters();
        }
    });

    function applyOverridesFromStorage() {
        const storedOverrides = localStorage.getItem('lcm_tools_overrides');
        if (storedOverrides) {
            try {
                const overrides = JSON.parse(storedOverrides);
                toolsData.forEach(t => {
                    const baseStem = t.Name.replace(/\.[^/.]+$/, "");
                    let matched = overrides[t.Name];
                    if (!matched) {
                        for (let k in overrides) {
                            if (k.replace(/\.[^/.]+$/, "").toLowerCase() === baseStem.toLowerCase()) {
                                matched = overrides[k];
                                break;
                            }
                        }
                    }
                    if (matched) {
                        Object.assign(t, matched);
                        if (matched.Group || matched.Subsystem || matched.Domain) {
                            const gVal = matched.Subsystem || matched.Group || matched.Domain;
                            t.Group = gVal;
                            t.Domain = gVal;
                            t.Subsystem = gVal;
                        }
                        t._edited = true;
                    }
                });
            } catch(e) {}
        }
    }

    applyOverridesFromStorage();

    // Add Env helper property
    toolsData.forEach(t => {
        const extMatch = t.Name.match(/\.([a-zA-Z0-9]+)$/);
        t.Env = extMatch ? extMatch[1].toUpperCase() : 'FILE';
        if (!t.ShortName) {
            t.ShortName = t.Name.replace(/\.[^/.]+$/, "");
        }
    });

    // Independent tab filters stored in sessionStorage
    const initialConfig = window.__LCM_CONFIG__ || {};
    let currentAudience = sessionStorage.getItem('lcm_tools_audience') || initialConfig.Audience || 'All';
    if (currentAudience === 'Dev') currentAudience = 'Developer';
    let currentGroup = sessionStorage.getItem('lcm_tools_group') || initialConfig.Group || 'All';
    let currentRole = sessionStorage.getItem('lcm_tools_role') || initialConfig.Role || 'All';
    let currentTool = sessionStorage.getItem('lcm_tools_tool') || initialConfig.Tool || 'All';
    let currentEnv = sessionStorage.getItem('lcm_tools_env') || initialConfig.Env || 'All';
    let currentAdmin = sessionStorage.getItem('lcm_tools_admin') || 'All';
    let searchFilter = sessionStorage.getItem('lcm_tools_search') || initialConfig.Filter || '';
    
    // View Mode: false = Short-Names (default), true = Source Files (Dev mode)
    let isSourceMode = sessionStorage.getItem('lcm_tools_sourcemode') === 'true';
    let sortField = 'Name';
    let sortAsc = true;

    const roleChoices = [
        'SystemInvariants', 'SystemCustomization', 'SystemRepair', 'SystemDiagnostics',
        'QualityGate', 'ReviewGate', 'InventoryAudit', 'InventoryQuery', 'InventoryTelemetry',
        'ToolDiscovery', 'ToolManagement', 'SubsystemAudit', 'SubsystemDiagnostics',
        'SubsystemRecovery', 'SubsystemAuth', 'DesktopGUI', 'Utility'
    ];

    function getExtClass(name) {
        const lower = name.toLowerCase();
        if (lower.endsWith('.ps1')) return { cls: 'ext-ps1', label: 'PS1' };
        if (lower.endsWith('.cmd')) return { cls: 'ext-cmd', label: 'CMD' };
        if (lower.endsWith('.py'))  return { cls: 'ext-py',  label: 'PY' };
        if (lower.endsWith('.reg')) return { cls: 'ext-reg', label: 'REG' };
        if (lower.endsWith('.lnk')) return { cls: 'ext-lnk', label: 'LNK' };
        return { cls: 'ext-lnk', label: 'FILE' };
    }

    function toggleViewMode() {
        isSourceMode = !isSourceMode;
        sessionStorage.setItem('lcm_tools_sourcemode', isSourceMode ? 'true' : 'false');
        updateViewModeUI();
        applyFilters();
    }

    function updateViewModeUI() {
        const btn = document.getElementById('tab-view-mode');
        const thName = document.getElementById('th-tool-name');
        if (btn) {
            if (isSourceMode) {
                btn.classList.add('active');
                btn.innerHTML = '<span style="font-size: 16px; line-height: 1;">📁</span> Mode: Code';
                btn.style.borderColor = 'var(--accent)';
                btn.style.background = 'rgba(88, 166, 255, 0.2)';
                btn.style.color = '#79c0ff';
                if (thName) {
                    thName.innerHTML = 'Source File <span class="sort-icon">⇅</span>';
                }
            } else {
                btn.classList.remove('active');
                btn.innerHTML = '<span style="font-size: 16px; line-height: 1;">💬</span> Mode: Short';
                btn.style.borderColor = '';
                btn.style.background = '';
                btn.style.color = '';
                if (thName) {
                    thName.innerHTML = 'Tool Name <span class="sort-icon">⇅</span>';
                }
            }
            autoAdjustColumnWidths();
        }
    }

    function renderTable(data) {
        const tbody = document.getElementById('tools-tbody');
        if (data.length === 0) {
            tbody.innerHTML = '<tr><td colspan="11" style="text-align: center; padding: 32px; color: var(--text-muted);">No matching tools found.</td></tr>';
            return;
        }

        tbody.innerHTML = data.map(t => {
            // Static sequence number assigned at compile time in Show-ToolsExplorer.ps1 (never dynamically browser-generated)
            const masterIdx = toolsData.findIndex(item => (item.RelativePath && t.RelativePath) ? (item.RelativePath === t.RelativePath) : (item.Name === t.Name));
            const safeIdx = masterIdx >= 0 ? masterIdx : 0;
            const idxNum = t.Index != null ? t.Index : (safeIdx + 1);
            let counter = String(idxNum);
            if (idxNum < 0) {
                counter = '-' + String(Math.abs(idxNum)).padStart(2, '0');
            } else if (idxNum > 0) {
                counter = String(idxNum).padStart(3, '0');
            }

            const ext = getExtClass(t.Name);
            let audBadge = '<span class="badge badge-dev">Dev</span>';
            if (t.Audience === 'User') {
                audBadge = '<span class="badge badge-user">User</span>';
            } else if (t.Audience === 'Internal') {
                audBadge = '<span class="badge badge-internal" style="background: #8957e5; color: #fff; font-weight: 600;">Internal</span>';
            }
            const admBadge = t.Admin ? '<span class="badge badge-admin-yes" title="ADMINMODE design criterion: elevation required">🛡️ Admin</span>' : '<span class="badge badge-admin-no" title="ADMINMODE design criterion: elevation not required">👤 User</span>';
            const editedMarker = t._edited ? '<span class="edited-tag" title="Cell overridden client-side">✏️</span>' : '';

            const extDisplay = '<span class="tool-ext-badge ' + ext.cls + '">' + ext.label + '</span>';

            // Display Name switched per user specification (no pictograms)
            const shortNameLabel = t.ShortName || t.Name.replace(/\.[^/.]+$/, "");
            const displayName = isSourceMode ? t.Name : shortNameLabel;

            let shortNamesListHtml = '';
            const allShortNames = getShortNamesForTool(t);
            if (isSourceMode) {
                const totalShortNames = allShortNames.length;
                shortNamesListHtml = '<div class="shortnames-container" style="display: flex; flex-direction: column; gap: 2px; margin-top: 4px;">' +
                    allShortNames.map(sn => {
                        const safeSn = escapeHtml(sn);
                        if (totalShortNames > 1) {
                            return '<span class="shortname-pill active-alias" style="display: inline-flex; align-items: center; justify-content: space-between; max-width: fit-content;" title="Short-name launcher: ' + safeSn + '.cmd">' +
                                '💬 ' + safeSn +
                                '<button type="button" class="btn-delete-shortname" onclick="window.LcmTools.deleteSpecificShortName(' + safeIdx + ', \'' + safeSn + '\', event)" title="Delete short-name launcher ' + safeSn + '.cmd (preserves underlying script)">✕</button>' +
                                '</span>';
                        } else {
                            return '<span class="shortname-pill protected-alias" style="display: inline-flex; align-items: center; max-width: fit-content;" title="Protected sole launcher">' +
                                '💬 ' + safeSn +
                                '<span style="margin-left: 4px; font-size: 10px;" title="Disallowed: Sole remaining launcher for this script (Last-Alias Invariant)">🔒</span>' +
                                '</span>';
                        }
                    }).join('') +
                    '</div>';
            } else {
                // In Short-Names mode, display active aliases (e.g. BCR) below primary ShortName stacked vertically
                const aliases = allShortNames.filter(sn => sn.toLowerCase() !== displayName.toLowerCase());
                if (aliases.length > 0) {
                    shortNamesListHtml = '<div class="shortnames-container" style="display: flex; flex-direction: column; gap: 2px; margin-top: 3px;">' +
                        aliases.map(sn => {
                            const safeSn = escapeHtml(sn);
                            return '<span class="shortname-pill active-alias" style="display: inline-block; max-width: fit-content;" title="Alias launcher: ' + safeSn + '.cmd">' +
                                '💬 ' + safeSn +
                                '</span>';
                        }).join('') +
                        '</div>';
                }
            }

            const noExitBadge = t.NoExit 
                ? '<span class="badge badge-noexit-true" onclick="window.LcmTools.toggleNoExit(' + safeIdx + ', event)" title="Click to toggle (Currently: Keep console open after execution)">🔴 NoExit</span>' 
                : '<span class="badge badge-noexit-false" onclick="window.LcmTools.toggleNoExit(' + safeIdx + ', event)" title="Click to toggle (Currently: Console may exit automatically)">🟢 May Exit</span>';

            const pendingInfo = getToolPendingInfo(t);
            const isBlocked = Boolean(pendingInfo || t.IsBlocked);
            let rowClass = '';
            if (pendingInfo) {
                rowClass = pendingInfo.type === 'delete' ? ' class="row-pending-delete"' : ' class="row-pending-modification"';
            }

            let actionButtonsHtml = '';
            if (isBlocked) {
                actionButtonsHtml = 
                    '<div class="action-btns">' +
                        '<span class="badge-no-entry" title="Tool execution blocked pending Set or Reset" style="font-size: 15px; cursor: default; user-select: none;">⛔</span>' +
                        '<button class="btn-action btn-revert" onclick="window.LcmTools.revertTool(' + safeIdx + ')" title="Reset changes, restore baseline, lift blockade" style="background: #0d1117 !important; color: #f85149 !important; border-color: rgba(248, 81, 73, 0.4) !important; font-weight: 700;">Reset</button>' +
                        '<button class="btn-action btn-finalize" onclick="window.LcmTools.finalizeTool(' + safeIdx + ')" title="Set changes permanently, lift blockade" style="background: #0d1117 !important; color: #3fb950 !important; border-color: rgba(63, 185, 80, 0.4) !important; font-weight: 700;">Set</button>' +
                    '</div>';
            } else {
                actionButtonsHtml = 
                    '<div class="action-btns">' +
                        '<button class="btn-action btn-run-action" onclick="window.LcmTools.openRunDialog(' + safeIdx + ')" title="Configure parameters and run...">▶ Run...</button>' +
                        '<button class="btn-action btn-menu-trigger" onclick="window.LcmTools.openActionMenu(' + safeIdx + ', event)" title="Select action">⋮ ▾</button>' +
                    '</div>';
            }

            return '<tr' + rowClass + '>' +
                '<td style="text-align: center; font-family: var(--font-mono); font-size: 11px; color: var(--text-muted); font-weight: 600;">' + counter + '</td>' +
                '<td>' +
                    '<div class="tool-name-cell" style="display: flex; flex-direction: column; align-items: flex-start;">' +
                        '<div style="display: flex; align-items: center; gap: 4px;">' +
                            '<a href="javascript:void(0)" class="tool-name-link" onclick="window.LcmTools.runToolSmart(' + safeIdx + ')" title="Run ' + displayName + ' with defaults (' + (t.Admin ? '🛡️ Elevated Admin' : '👤 Standard User') + ')">' +
                                displayName +
                            '</a>' +
                            editedMarker +
                        '</div>' +
                        shortNamesListHtml +
                    '</div>' +
                '</td>' +
                '<td style="text-align: center;">' + actionButtonsHtml + '</td>' +
                '<td class="cell-editable" onclick="window.LcmTools.openCellEditor(' + safeIdx + ', \'SubSystem\', event)" title="Click to edit SubSystem"><span class="badge badge-subsystem">' + (t.SubSystem || t.Subsystem || t.Group || t.Domain || '') + '</span></td>' +
                '<td class="col-desc cell-editable" onclick="window.LcmTools.openCellEditor(' + safeIdx + ', \'Description\', event)" title="Click to edit Description" style="cursor: pointer;">' + (t.Description || '') + '</td>' +
                '<td class="cell-editable" onclick="window.LcmTools.openCellEditor(' + safeIdx + ', \'Category\', event)" style="color: #c9d1d9;">' + (t.Category || 'General') + '</td>' +
                '<td class="cell-editable" onclick="window.LcmTools.openCellEditor(' + safeIdx + ', \'Audience\', event)">' + audBadge + '</td>' +
                '<td style="text-align: center;">' + extDisplay + '</td>' +
                '<td class="cell-editable" onclick="window.LcmTools.openCellEditor(' + safeIdx + ', \'Admin\', event)">' + admBadge + '</td>' +
                '<td style="text-align: center;">' + noExitBadge + '</td>' +
                '</tr>';
        }).join('');

        autoAdjustColumnWidths();
    }

    function autoAdjustColumnWidths() {
        const container = document.querySelector('.table-container');
        const containerW = container ? container.clientWidth : window.innerWidth;
        const isNarrow = containerW < 1400;

        // Measure Tool Name column
        const thToolName = document.getElementById('th-tool-name');
        if (thToolName) {
            const toolLinks = document.querySelectorAll('.tool-name-link');
            let maxLen = 0;
            toolLinks.forEach((el, idx) => {
                if (idx < 60) {
                    const textLen = el.textContent.trim().length;
                    if (textLen > maxLen) maxLen = textLen;
                }
            });
            // Calculate width based on mode and longest visible item, auto-adjusting for viewport width
            let calculatedWidth;
            if (isSourceMode) {
                const base = Math.round(maxLen * 8.0 + 30);
                calculatedWidth = isNarrow 
                    ? Math.max(190, Math.min(320, base))
                    : Math.max(210, Math.min(400, base));
            } else {
                const base = Math.round(maxLen * 7.5 + 24);
                calculatedWidth = isNarrow 
                    ? Math.max(140, Math.min(240, base))
                    : Math.max(150, Math.min(280, base));
            }
            thToolName.style.width = calculatedWidth + 'px';
            thToolName.style.minWidth = calculatedWidth + 'px';
            thToolName.style.maxWidth = calculatedWidth + 'px';
        }

        // Measure Dropdown columns based on active selected value
        const adjustDropdownCol = (thId, selectId, baseWidth, maxAllowed) => {
            const th = document.getElementById(thId);
            const sel = document.getElementById(selectId);
            if (!th || !sel) return;
            const selText = sel.options && sel.selectedIndex >= 0 ? sel.options[sel.selectedIndex].text : '';
            if (!sel.value || sel.value === 'All') {
                th.style.width = baseWidth + 'px';
                th.style.minWidth = baseWidth + 'px';
                th.style.maxWidth = baseWidth + 'px';
            } else {
                const needed = Math.max(baseWidth, Math.min(maxAllowed, Math.round(selText.length * 8.0 + 26)));
                th.style.width = needed + 'px';
                th.style.minWidth = needed + 'px';
                th.style.maxWidth = needed + 'px';
            }
        };

        adjustDropdownCol(document.getElementById('th-col-subsystem') ? 'th-col-subsystem' : 'th-col-group', document.getElementById('subsystem-select') ? 'subsystem-select' : 'group-select', 75, 190);
        adjustDropdownCol('th-col-category', 'category-select', 90, 200);
        adjustDropdownCol('th-col-audience', 'audience-select', 80, 140);
    }

    // Dynamic Live Resize Listener: auto-shrinks and auto-widens columns on window resize
    let resizeDebounceTimer = null;
    window.addEventListener('resize', () => {
        clearTimeout(resizeDebounceTimer);
        resizeDebounceTimer = setTimeout(() => {
            autoAdjustColumnWidths();
        }, 50);
    });

    // -------------------------------------------------------------------------
    // Action Dropdown Menu Logic
    // -------------------------------------------------------------------------
    function openActionMenu(idx, event) {
        if (event) {
            event.stopPropagation();
            event.preventDefault();
        }
        activeMenuTool = toolsData[idx];
        const menu = document.getElementById('action-dropdown-menu');
        if (!menu) return;

        menu.classList.add('show');
        
        // Position relative to click target
        const btn = event.target.closest('button');
        const rect = btn.getBoundingClientRect();
        
        let top = rect.bottom + window.scrollY + 4;
        let left = rect.right + window.scrollX - 220;
        if (left < 10) left = 10;
        if (top + 320 > window.innerHeight + window.scrollY) {
            top = rect.top + window.scrollY - 320;
        }

        menu.style.top = top + 'px';
        menu.style.left = left + 'px';
    }

    function closeActionMenu() {
        const menu = document.getElementById('action-dropdown-menu');
        if (menu) menu.classList.remove('show');
    }

    document.addEventListener('click', (e) => {
        if (!e.target.closest('#action-dropdown-menu') && !e.target.closest('.btn-menu-trigger')) {
            closeActionMenu();
        }
    });

    function menuAction(actionType) {
        closeActionMenu();
        if (!activeMenuTool) return;
        const masterIdx = toolsData.findIndex(t => t.Name === activeMenuTool.Name);
        const safeIdx = masterIdx >= 0 ? masterIdx : 0;

        switch (actionType) {
            case 'run_params':
                openRunDialog(safeIdx);
                break;
            case 'tool_help':
                openToolHelp(activeMenuTool);
                break;
            case 'copy':
                copyCommand(activeMenuTool.Example);
                break;
            case 'inspect':
                openDetails(safeIdx);
                break;
            case 'edit':
                openInCodeEditor(activeMenuTool);
                break;
            case 'rename':
                openRenameModal(safeIdx);
                break;
            case 'cleanup':
                openCleanupModal(safeIdx);
                break;
            case 'archive':
                confirmAndArchiveTool(activeMenuTool);
                break;
            case 'delete':
                confirmAndDeleteTool(activeMenuTool);
                break;
        }
    }

    // -------------------------------------------------------------------------
    // Privileged Actions: Code Editor, Rename, Cleanup, Archive
    // -------------------------------------------------------------------------
    function openInCodeEditor(tool) {
        showToast('💻 Launching code editor for ' + tool.Name + '...');
        fetch(DAEMON_URL + '/open_editor', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ filePath: tool.RelativePath || ('tools/' + tool.Name), line: 1 })
        }).then(async response => {
            const data = await response.json();
            if (!response.ok || data.error) throw new Error(data.error || `HTTP ${response.status}`);
            showToast('✓ Opened in ' + (data.editor || 'IDE'));
        }).catch(error => {
            showToast('Editor dispatch failed: ' + error.message);
        });
    }

    function openRenameModal(idx) {
        activeRenameTool = toolsData[idx];
        const modal = document.getElementById('rename-modal-overlay');
        const inputSrc = document.getElementById('rename-input-source');
        const inputShort = document.getElementById('rename-input-short');
        
        if (inputSrc) {
            inputSrc.value = activeRenameTool.Name;
            inputSrc.disabled = false;
        }
        if (inputShort) {
            inputShort.value = activeRenameTool.ShortName || activeRenameTool.Name.replace(/\.[^/.]+$/, "");
        }
        
        modalAliases = Array.isArray(activeRenameTool.Aliases) ? [...activeRenameTool.Aliases] : [];
        const existingShorts = getShortNamesForTool(activeRenameTool);
        const primary = (inputShort ? inputShort.value : '').toLowerCase();
        existingShorts.forEach(sn => {
            if (sn.toLowerCase() !== primary && !modalAliases.some(a => a.toLowerCase() === sn.toLowerCase())) {
                modalAliases.push(sn);
            }
        });
        renderModalAliasTags();

        if (modal) modal.style.display = 'flex';
    }

    function renderModalAliasTags() {
        const container = document.getElementById('rename-aliases-tags');
        if (!container) return;
        if (modalAliases.length === 0) {
            container.innerHTML = '<span style="font-size: 11px; color: var(--text-muted); font-style: italic;">No additional aliases configured.</span>';
            return;
        }
        container.innerHTML = modalAliases.map((alias, i) => {
            const safe = escapeHtml(alias);
            return '<span class="shortname-pill active-alias" style="display: inline-flex; align-items: center; gap: 4px; padding: 2px 8px;">' +
                '💬 ' + safe +
                '<button type="button" onclick="window.LcmTools.removeModalAlias(' + i + ')" style="background: none; border: none; color: #f85149; font-weight: bold; cursor: pointer; padding: 0 2px; font-size: 12px;" title="Remove alias ' + safe + '">×</button>' +
                '</span>';
        }).join('');
    }

    function addModalAlias() {
        const input = document.getElementById('rename-new-alias-input');
        if (!input) return;
        const val = input.value.trim().replace(/\.cmd$/i, '');
        if (!val) return;
        if (modalAliases.some(a => a.toLowerCase() === val.toLowerCase())) {
            alert('Alias already exists: ' + val);
            return;
        }
        modalAliases.push(val);
        input.value = '';
        renderModalAliasTags();
    }

    function removeModalAlias(idx) {
        modalAliases.splice(idx, 1);
        renderModalAliasTags();
    }

    function updateDeleteShortNameUI() {
        if (!activeRenameTool) return;
        const countInfo = document.getElementById('rename-alias-count-info');
        const statusMsg = document.getElementById('rename-delete-status-msg');
        const btnDelete = document.getElementById('btn-delete-short');
        const aliases = activeRenameTool._matchingAliases || [];
        const count = aliases.length;

        if (countInfo) {
            if (count > 0) {
                countInfo.innerText = `Active launchers: ${count} (${aliases.join(', ')})`;
            } else {
                countInfo.innerText = 'Active launchers: 1 (' + (activeRenameTool.ShortName || 'default') + ')';
            }
        }

        if (statusMsg && btnDelete) {
            if (count <= 1) {
                statusMsg.innerHTML = `<span style="color: #f85149; font-weight: 700;">⚠️ Disallowed (Last-Alias Protection)</span>: <code>${activeRenameTool.ShortName || activeRenameTool.Name}</code> is the only short-name launcher for this script. Every script must retain at least one short name.`;
                btnDelete.disabled = true;
                btnDelete.style.opacity = '0.45';
                btnDelete.style.cursor = 'not-allowed';
                btnDelete.title = 'Disallowed: Last short name for this script.';
            } else {
                statusMsg.innerHTML = `<span style="color: #3fb950; font-weight: 700;">✓ Safe to delete</span>: Found <strong>${count}</strong> short-name launchers for this script. Deleting this alias leaves <strong>${count - 1}</strong> active launcher(s) intact.`;
                btnDelete.disabled = false;
                btnDelete.style.opacity = '1.0';
                btnDelete.style.cursor = 'pointer';
                btnDelete.title = 'Delete this short name launcher only.';
            }
        }
    }

    function toggleDeleteShortName(checked) {
        const btnSave = document.getElementById('btn-save-rename');
        const btnDelete = document.getElementById('btn-delete-short');
        const inputSrc = document.getElementById('rename-input-source');
        const statusMsg = document.getElementById('rename-delete-status-msg');

        if (checked) {
            if (btnSave) btnSave.style.display = 'none';
            if (btnDelete) btnDelete.style.display = 'inline-block';
            if (inputSrc) inputSrc.disabled = true;
            if (statusMsg) statusMsg.style.display = 'block';
            updateDeleteShortNameUI();
        } else {
            if (btnSave) btnSave.style.display = 'inline-block';
            if (btnDelete) btnDelete.style.display = 'none';
            if (inputSrc) inputSrc.disabled = false;
            if (statusMsg) statusMsg.style.display = 'none';
        }
    }

    function executeDeleteShortName() {
        if (!activeRenameTool) return;
        const targetShort = (document.getElementById('rename-input-short').value || activeRenameTool.ShortName || '').trim();
        const aliases = activeRenameTool._matchingAliases || [];

        if (aliases.length <= 1) {
            alert(`DISALLOWED: '${targetShort}' is the last remaining short-name launcher for '${activeRenameTool.Name}'. Every tool must retain at least one active short-name.`);
            return;
        }

        if (!confirm(`Are you sure you want to delete short-name launcher '${targetShort}.cmd'?\n\nPreserved Script: ${activeRenameTool.Name}\nRemaining Launchers: ${aliases.filter(x => x.toLowerCase() !== targetShort.toLowerCase()).join(', ')}\n\nThe underlying script file will NOT be deleted.`)) {
            return;
        }

        showToast(`🗑️ Deleting short name '${targetShort}.cmd'...`);
        fetch(DAEMON_URL + '/delete_short_name', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                shortName: targetShort,
                targetScript: activeRenameTool.Name
            })
        }).then(r => r.json()).then(data => {
            if (data.error || data.status === 'DISALLOWED') {
                alert('Deletion disallowed / failed: ' + (data.error || 'Last-alias protection violation'));
            } else {
                showToast(`✓ Removed launcher '${targetShort}.cmd' (Script preserved intact)`);
                closeRenameModal();
                setTimeout(() => { refreshToolCatalog(); }, 600);
            }
        }).catch(err => {
            alert('Daemon request failed: ' + err.message);
        });
    }

    async function deleteSpecificShortName(safeIdx, targetShort, event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        const t = toolsData[safeIdx];
        if (!t) return;

        const aliases = getShortNamesForTool(t);
        if (aliases.length <= 1) {
            alert(`DISALLOWED: '${targetShort}' is the last remaining short-name launcher for '${t.Name}'. Every script must retain at least one short-name launcher.`);
            return;
        }

        const remaining = aliases.filter(x => x.toLowerCase() !== targetShort.toLowerCase());
        const confirmMsg = `Are you sure you want to delete short-name launcher '${targetShort}.cmd'?\n\nPreserved Script: ${t.Name} (Retained intact)\nRemaining Launchers (${remaining.length}): ${remaining.join(', ')}\n\nOnly the launcher in LCM_Inventory\\Cmd\\ will be deleted. The source script will NOT be touched.`;
        if (!confirm(confirmMsg)) {
            return;
        }

        showToast(`🗑️ Deleting short name '${targetShort}.cmd'...`);
        try {
            const resp = await fetch(DAEMON_URL + '/delete_short_name', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    shortName: targetShort,
                    targetScript: t.Name
                })
            });
            const data = await resp.json();
            if (data.error || data.status === 'DISALLOWED') {
                alert('Deletion disallowed: ' + (data.error || 'Last-alias protection violation'));
            } else {
                showToast(`✓ Removed launcher '${targetShort}.cmd' (Script preserved intact)`);
                
                // Prune from local map
                const leaf = t.Name.split(/[/\\]/).pop();
                if (allShortNamesMap[t.Name]) {
                    allShortNamesMap[t.Name] = allShortNamesMap[t.Name].filter(x => x.toLowerCase() !== targetShort.toLowerCase());
                }
                if (allShortNamesMap[leaf]) {
                    allShortNamesMap[leaf] = allShortNamesMap[leaf].filter(x => x.toLowerCase() !== targetShort.toLowerCase());
                }
                if (t.ShortName && t.ShortName.toLowerCase() === targetShort.toLowerCase()) {
                    t.ShortName = remaining[0] || '';
                }
                if (Array.isArray(t.Aliases)) {
                    t.Aliases = t.Aliases.filter(x => x.toLowerCase() !== targetShort.toLowerCase());
                }

                // Sync across any duplicate representations in toolsData
                toolsData.forEach(item => {
                    if (item.Name === t.Name) {
                        item.ShortName = t.ShortName;
                        item.Aliases = t.Aliases;
                    }
                });

                if (syncChannel) {
                    syncChannel.postMessage({ type: 'CATALOG_UPDATED' });
                }

                applyFilters();
            }
        } catch(err) {
            console.error('Delete short-name error:', err);
            alert(`Error communicating with LCM Daemon: ${err.message}`);
        }
    }

    function closeRenameModal(e) {
        if (!e || e === true || e.target.id === 'rename-modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-reset')) {
            const modal = document.getElementById('rename-modal-overlay');
            if (modal) modal.style.display = 'none';
            activeRenameTool = null;
        }
    }

    function executeRename() {
        if (!activeRenameTool) return;
        const newSrc = (document.getElementById('rename-input-source').value || '').trim();
        const newShort = (document.getElementById('rename-input-short').value || '').trim();

        if (!newSrc || !newShort) {
            alert('Both source filename and short-name alias must be specified.');
            return;
        }

        showToast('✏️ Renaming ' + activeRenameTool.Name + '...');
        fetch(DAEMON_URL + '/rename', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                oldName: activeRenameTool.Name,
                newName: newSrc,
                oldShortName: activeRenameTool.ShortName,
                newShortName: newShort,
                relativePath: activeRenameTool.RelativePath,
                aliases: modalAliases
            })
        }).then(r => r.json()).then(async data => {
            if (data.error) {
                alert('Rename failed: ' + data.error);
            } else {
                activeRenameTool.ShortName = newShort;
                activeRenameTool.Aliases = modalAliases;
                showToast('✓ Renamed to ' + newShort + ' (' + newSrc + ')');
                closeRenameModal();
                if (window.LcmDisplay) await window.LcmDisplay.refresh();
            }
        }).catch(err => {
            alert('Connection to REST daemon (Port 9876) failed: ' + err.message);
        });
    }

    function openCleanupModal(idx) {
        activeCleanupTool = toolsData[idx];
        const modal = document.getElementById('cleanup-modal-overlay');
        const title = document.getElementById('cleanup-modal-title');
        const logsInfo = document.getElementById('cleanup-logs-info');
        const archiveInfo = document.getElementById('cleanup-archive-info');

        if (title) title.innerText = '🧹 Cleanup: ' + (activeCleanupTool.ShortName || activeCleanupTool.Name);
        if (logsInfo) logsInfo.innerText = 'Querying audit logs in tools/logs/...';
        if (archiveInfo) archiveInfo.innerText = 'Querying archived snapshots in LCM_Inventory/tools/archive/...';

        if (modal) modal.style.display = 'flex';

        // Query daemon for real sizes
        fetch(DAEMON_URL + '/query_cleanup', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                toolName: activeCleanupTool.Name,
                shortName: activeCleanupTool.ShortName
            })
        }).then(r => r.json()).then(data => {
            if (data.status === 'OK') {
                const logKb = (data.logBytes / 1024).toFixed(1);
                const archKb = (data.archiveBytes / 1024).toFixed(1);
                if (logsInfo) logsInfo.innerText = data.logCount + ' log files found (' + logKb + ' KB total)';
                if (archiveInfo) archiveInfo.innerText = data.archiveCount + ' snapshots found (' + archKb + ' KB total)';
            }
        }).catch(e => {
            if (logsInfo) logsInfo.innerText = 'tools/logs/' + activeCleanupTool.Name + '-*.log';
            if (archiveInfo) archiveInfo.innerText = 'LCM_Inventory/tools/archive/' + activeCleanupTool.Name.replace(/\.[^/.]+$/, "") + '/';
        });
    }

    function closeCleanupModal(e) {
        if (!e || e === true || e.target.id === 'cleanup-modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-reset')) {
            const modal = document.getElementById('cleanup-modal-overlay');
            if (modal) modal.style.display = 'none';
            activeCleanupTool = null;
        }
    }

    function executeCleanup() {
        if (!activeCleanupTool) return;
        const purgeLogs = document.getElementById('cleanup-chk-logs').checked;
        const purgeArchive = document.getElementById('cleanup-chk-archive').checked;

        if (!purgeLogs && !purgeArchive) {
            alert('Please select at least one artifact category to purge.');
            return;
        }

        showToast('🧹 Purging artifact history for ' + activeCleanupTool.Name + '...');
        fetch(DAEMON_URL + '/cleanup', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                toolName: activeCleanupTool.Name,
                shortName: activeCleanupTool.ShortName,
                purgeLogs: purgeLogs,
                purgeArchive: purgeArchive
            })
        }).then(r => r.json()).then(data => {
            if (data.error) {
                alert('Cleanup failed: ' + data.error);
            } else {
                const kb = (data.freedBytes / 1024).toFixed(1);
                showToast('✓ Cleaned ' + data.deletedCount + ' files (' + kb + ' KB freed)');
                closeCleanupModal();
            }
        }).catch(err => {
            alert('Connection to REST daemon (Port 9876) failed: ' + err.message);
        });
    }

    function confirmAndArchiveTool(tool) {
        if (!confirm('Are you sure you want to archive "' + tool.Name + '"?\n\nThis will move the script to LCM_Inventory/tools/archive/ and remove its active command launcher.')) {
            return;
        }
        showToast('📦 Archiving ' + tool.Name + '...');
        fetch(DAEMON_URL + '/archive', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                toolName: tool.Name,
                relativePath: tool.RelativePath
            })
        }).then(r => r.json()).then(async data => {
            if (data.error) {
                alert('Archive failed: ' + data.error);
            } else {
                showToast('✓ Archived to ' + data.archiveTarget);
                if (window.LcmDisplay) await window.LcmDisplay.refresh();
            }
        }).catch(err => {
            alert('Daemon request failed: ' + err.message);
        });
    }

    function confirmAndDeleteTool(tool) {
        if (!confirm('⚠️ PERMANENT DELETE WARNING ⚠️\n\nAre you sure you want to delete "' + tool.Name + '"?\nConsider using Archive instead.')) {
            return;
        }
        showToast('To delete safely, please use the Archive action or terminal git rm.');
    }

    function toggleNoExit(idx, event) {
        if (event) event.stopPropagation();
        const tool = toolsData[idx];
        if (!tool) return;
        
        const newVal = !tool.NoExit;
        const baseStem = tool.Name.replace(/\.[^/.]+$/, "");
        
        let stored = {};
        try { stored = JSON.parse(localStorage.getItem('lcm_tools_overrides') || '{}'); } catch(e) {}
        
        let count = 0;
        toolsData.forEach(t => {
            const stem = t.Name.replace(/\.[^/.]+$/, "");
            if (stem.toLowerCase() === baseStem.toLowerCase()) {
                t.NoExit = newVal;
                t._edited = true;
                if (!stored[t.Name]) stored[t.Name] = {};
                stored[t.Name].NoExit = newVal;
                count++;
            }
        });
        
        localStorage.setItem('lcm_tools_overrides', JSON.stringify(stored));
        
        if (syncChannel) {
            syncChannel.postMessage({ type: 'CATALOG_UPDATED', timestamp: Date.now() });
        }
        
        applyFilters();
        showToast((newVal ? '🔴 NoExit locked (Keep Open)' : '🟢 Auto-Exit enabled') + ' for ' + baseStem + ' (' + count + ' envs)');
    }

    function updateSubsystemCard(subsystemName) {
        const cardLabel = document.getElementById('card-subsystem-label');
        const cardValue = document.getElementById('card-subsystem-value');
        const cardSub = document.getElementById('card-subsystem-sub');
        if (!cardLabel || !cardValue) return;

        const isAll = !subsystemName || subsystemName === 'All';
        cardLabel.innerText = isAll ? 'All Subsystems' : (subsystemName + ' Subsystem');
        
        const count = isAll
            ? toolsData.length
            : toolsData.filter(t => t.Group === subsystemName || t.Domain === subsystemName || (subsystemName === 'HaSSD06' && (t.Group === 'HaSSD06' || (t.Domain && t.Domain.startsWith('HaSSD06'))))).length;
        
        cardValue.innerText = count;
        if (cardSub) cardSub.innerText = isAll ? 'Complete Catalog' : 'Selected Subsystem';
    }

    function filterBySubsystem(subsystemName) {
        document.querySelectorAll('.metric-card').forEach(c => c.classList.remove('active'));
        const card = document.getElementById('card-subsystem');
        if (card) card.classList.add('active');
        resetColumnFilters(false);
        const grp = document.getElementById('group-select');
        if (grp) grp.value = subsystemName;
        const headerGrp = document.getElementById('header-subsystem-select');
        if (headerGrp) headerGrp.value = subsystemName;
        setAudienceTab('All');
        applyFilters();
        showToast('🔍 Filtered to ' + (subsystemName === 'All' ? 'All Subsystems' : subsystemName + ' Subsystem'));
    }

    function matchQuery(text, query) {
        if (!query || query === 'All') return true;
        const target = (text || '').toLowerCase();
        const q = query.toLowerCase().trim();
        if (!q) return true;

        const tokens = q.split(/\s+/);
        for (const token of tokens) {
            const isNegation = token.startsWith('!');
            const cleanToken = isNegation ? token.slice(1) : token;
            if (!cleanToken) continue;

            const alts = cleanToken.split('|').filter(Boolean);
            if (alts.length === 0) continue;

            const matchesAny = alts.some(alt => target.includes(alt));
            if (isNegation && matchesAny) return false;
            if (!isNegation && !matchesAny) return false;
        }
        return true;
    }

    function matchRowSearch(tool, query) {
        if (!query) return true;
        const tokens = query.trim().split(/\s+/);

        for (const rawToken of tokens) {
            if (!rawToken) continue;
            const isNegation = rawToken.startsWith('!');
            const token = isNegation ? rawToken.slice(1) : rawToken;
            if (!token) continue;

            // Support pipe | alternation: term1|term2|term3 (OR within token)
            const alternatives = token.split('|').filter(Boolean);
            if (alternatives.length === 0) continue;

            const matchesAnyAlternative = alternatives.some(alt => {
                const colonIdx = alt.indexOf(':');
                if (colonIdx > 0) {
                    const colKey = alt.slice(0, colonIdx).toLowerCase();
                    const colVal = alt.slice(colonIdx + 1).toLowerCase();
                    let fieldVal = '';

                    switch (colKey) {
                        case 'group':
                        case 'subsystem':
                            fieldVal = (tool.Group || '') + ' ' + (tool.Domain || '');
                            break;
                        case 'env':
                            fieldVal = tool.Env || '';
                            break;
                        case 'role':
                            fieldVal = tool.Role || '';
                            break;
                        case 'aud':
                        case 'audience':
                            fieldVal = tool.Audience || '';
                            break;
                        case 'admin':
                            fieldVal = String(Boolean(tool.Admin));
                            break;
                        case 'noexit':
                            fieldVal = String(Boolean(tool.NoExit));
                            break;
                        case 'cat':
                        case 'category':
                            fieldVal = tool.Category || '';
                            break;
                        case 'name':
                        case 'tool':
                            fieldVal = (tool.Name || '') + ' ' + (tool.ShortName || '');
                            break;
                        case 'desc':
                        case 'description':
                            fieldVal = tool.Description || '';
                            break;
                        default:
                            fieldVal = [
                                tool.Name, tool.ShortName || '', tool.Description || '',
                                tool.Role || '', tool.Category || '', tool.Group || '',
                                tool.Domain || '', tool.Env || ''
                            ].join(' ');
                            break;
                    }

                    return fieldVal.toLowerCase().includes(colVal);
                } else {
                    const fullContent = [
                        tool.Name,
                        tool.ShortName || '',
                        tool.Description || '',
                        tool.Role || '',
                        tool.Category || '',
                        tool.Group || '',
                        tool.Domain || '',
                        tool.Env || ''
                    ].join(' ').toLowerCase();

                    return fullContent.includes(alt.toLowerCase());
                }
            });

            if (isNegation && matchesAnyAlternative) return false;
            if (!isNegation && !matchesAnyAlternative) return false;
        }
        return true;
    }

    function applyFilters() {
        const search = (document.getElementById('search-input') ? document.getElementById('search-input').value : '').trim();
        const toolVal = document.getElementById('tool-select') ? document.getElementById('tool-select').value : 'All';
        const envVal = document.getElementById('env-select') ? document.getElementById('env-select').value : 'All';
        const subSelect = document.getElementById('subsystem-select') || document.getElementById('group-select');
        const groupVal = subSelect ? subSelect.value : 'All';
        const audVal = document.getElementById('audience-select') ? document.getElementById('audience-select').value : 'All';
        const adminVal = document.getElementById('admin-select') ? document.getElementById('admin-select').value : 'All';
        const noexitVal = document.getElementById('noexit-select') ? document.getElementById('noexit-select').value : 'All';
        const catVal = document.getElementById('category-select') ? document.getElementById('category-select').value : 'All';
        const descFilter = (document.getElementById('desc-filter') ? document.getElementById('desc-filter').value : '').trim();

        // Persist filter state independently per tab in sessionStorage
        sessionStorage.setItem('lcm_tools_search', search);
        sessionStorage.setItem('lcm_tools_tool', toolVal);
        sessionStorage.setItem('lcm_tools_env', envVal);
        sessionStorage.setItem('lcm_tools_subsystem', groupVal);
        sessionStorage.setItem('lcm_tools_group', groupVal);
        sessionStorage.setItem('lcm_tools_admin', adminVal);
        sessionStorage.setItem('lcm_tools_noexit', noexitVal);
        sessionStorage.setItem('lcm_tools_category', catVal);
        sessionStorage.setItem('lcm_tools_audience', currentAudience);
        sessionStorage.setItem('lcm_tools_sort_field', sortField);
        sessionStorage.setItem('lcm_tools_sort_asc', sortAsc ? 'true' : 'false');
        sessionStorage.setItem('lcm_tools_internal_filter', isFilteringInternal ? '1' : '0');
        sessionStorage.setItem('lcm_tools_show_filter', isShowToolsButtonOn ? '1' : '0');

        const headerGrp = document.getElementById('header-subsystem-select');
        if (headerGrp && headerGrp.value !== groupVal && groupVal !== 'All' && groupVal !== '') {
            headerGrp.value = groupVal;
        } else if (headerGrp && groupVal === 'All') {
            headerGrp.value = 'All';
        }

        let filtered = toolsData.filter(t => {
            const matchesIntern = (s) => typeof s === 'string' && s.trim().toLowerCase().startsWith('intern');
            const isItemInternal = matchesIntern(t.Audience) || 
                                   matchesIntern(t.Category) || 
                                   matchesIntern(t.Group) || 
                                   matchesIntern(t.Domain);

            // 1. Internal Suppression Rule:
            // When isFilteringInternal is false (Int. button OFF), items with "Intern*"
            // are suppressed unless explicitly requested via specific filter dropdowns.
            if (isItemInternal && !isFilteringInternal && audVal !== 'Internal' && !matchesIntern(catVal) && !matchesIntern(groupVal)) {
                return false;
            }

            // 2. Audience Filter Matching:
            let matchAud = true;
            if (audVal === 'All') {
                matchAud = true;
            } else if (audVal === 'Internal') {
                matchAud = isItemInternal || (t.Audience && t.Audience.toLowerCase() === 'internal');
            } else if (audVal === 'Dev' || audVal === 'Developer') {
                matchAud = (t.Audience === 'Developer' || t.Audience === 'Dev');
            } else if (audVal === 'User') {
                matchAud = (t.Audience && t.Audience.toLowerCase() === 'user');
            } else {
                matchAud = (t.Audience && t.Audience.toLowerCase() === audVal.toLowerCase());
            }

            const matchTool = (toolVal === 'All') || (t.Name === toolVal) || (t.ShortName === toolVal);
            const matchEnv = (envVal === 'All') || (t.Env === envVal.toUpperCase());
            const matchGroup = (groupVal === 'All') || 
                (t.SubSystem === groupVal) || 
                (t.Subsystem === groupVal) || 
                (t.Group === groupVal) || 
                (t.Domain === groupVal) || 
                (groupVal === 'HaSSD06' && ((t.SubSystem && t.SubSystem.startsWith('HaSSD06')) || (t.Group && t.Group.startsWith('HaSSD06')) || (t.Domain && t.Domain.startsWith('HaSSD06'))));
            
            const matchAdmin = (adminVal === 'All') || (adminVal === 'Admin' && t.Admin) || (adminVal === 'User' && !t.Admin);
            const matchNoExit = (noexitVal === 'All') || (noexitVal === 'true' && t.NoExit) || (noexitVal === 'false' && !t.NoExit);
            const matchCat = (catVal === 'All') || (t.Category === catVal);
            const matchDesc = matchQuery(t.Description, descFilter);
            const matchSearch = matchRowSearch(t, search);
            const matchShowFilter = !isManualShowToolsFilter || (
                (t.Name && (t.Name.toLowerCase().startsWith('show-') || t.Name.toLowerCase().startsWith('show'))) ||
                (t.ShortName && (t.ShortName.toLowerCase().startsWith('show-') || t.ShortName.toLowerCase().startsWith('show')))
            );

            return matchAud && matchTool && matchEnv && matchGroup && matchAdmin && matchNoExit && matchCat && matchDesc && matchSearch && matchShowFilter;
        });

        filtered.sort((a, b) => {
            if (sortField === 'Index') {
                const idxA = (a.Index != null) ? a.Index : toolsData.findIndex(x => x.Name === a.Name);
                const idxB = (b.Index != null) ? b.Index : toolsData.findIndex(x => x.Name === b.Name);
                return sortAsc ? (idxA - idxB) : (idxB - idxA);
            }
            const field = (!isSourceMode && sortField === 'Name') ? 'ShortName' : sortField;
            let valA = (a[field] !== undefined ? a[field] : '').toString().toLowerCase();
            let valB = (b[field] !== undefined ? b[field] : '').toString().toLowerCase();
            return sortAsc ? (valA < valB ? -1 : (valA > valB ? 1 : 0)) : (valA > valB ? -1 : (valA < valB ? 1 : 0));
        });

        updateSubsystemCard(groupVal);
        currentFilteredTools = filtered;
        renderTable(filtered);

        // Update Total / Selected Tools metric card display
        const cardAllVal = document.getElementById('card-all-value');
        if (cardAllVal) {
            cardAllVal.textContent = toolsData.length + ' / ' + filtered.length;
        }
    }

    function setAudienceTab(aud) {
        if (aud === 'Dev') aud = 'Developer';
        currentAudience = aud;
        document.querySelectorAll('.tab-btn').forEach(btn => {
            if (btn.id !== 'tab-view-mode') btn.classList.remove('active');
        });
        if (aud === 'User') {
            const b = document.getElementById('tab-user'); if (b) b.classList.add('active');
        } else if (aud === 'Developer') {
            const b = document.getElementById('tab-dev'); if (b) b.classList.add('active');
        } else {
            const b = document.getElementById('tab-all'); if (b) b.classList.add('active');
        }
        
        const audSelect = document.getElementById('audience-select');
        if (audSelect) {
            audSelect.value = (aud === 'Developer' ? 'Developer' : (aud === 'User' ? 'User' : 'All'));
        }

        sessionStorage.setItem('lcm_tools_audience', currentAudience);
        applyFilters();
    }

    function filterByCard(cardType) {
        document.querySelectorAll('.metric-card').forEach(c => c.classList.remove('active'));

        if (cardType === 'all') {
            document.getElementById('card-all').classList.add('active');
            resetColumnFilters(false);
            setAudienceTab('All');
        } else if (cardType === 'user') {
            document.getElementById('card-user').classList.add('active');
            resetColumnFilters(false);
            setAudienceTab('User');
        } else if (cardType === 'admin') {
            document.getElementById('card-admin').classList.add('active');
            resetColumnFilters(false);
            document.getElementById('admin-select').value = 'Admin';
            setAudienceTab('All');
        } else if (cardType === 'noexit') {
            const c = document.getElementById('card-noexit'); if (c) c.classList.add('active');
            resetColumnFilters(false);
            if (document.getElementById('noexit-select')) document.getElementById('noexit-select').value = 'true';
            setAudienceTab('All');
        } else if (cardType === 'invariants') {
            document.getElementById('card-invariants').classList.add('active');
            resetColumnFilters(false);
            const catSel = document.getElementById('category-select');
            if (catSel) {
                const opt = Array.from(catSel.options).find(o => /invariant/i.test(o.value));
                if (opt) catSel.value = opt.value;
            }
            setAudienceTab('All');
        } else if (cardType === 'customizations') {
            document.getElementById('card-customizations').classList.add('active');
            resetColumnFilters(false);
            const catSel = document.getElementById('category-select');
            if (catSel) {
                const opt = Array.from(catSel.options).find(o => /customization/i.test(o.value));
                if (opt) catSel.value = opt.value;
            }
            setAudienceTab('All');
        } else if (cardType === 'repair') {
            document.getElementById('card-repair').classList.add('active');
            resetColumnFilters(false);
            const catSel = document.getElementById('category-select');
            if (catSel) {
                const opt = Array.from(catSel.options).find(o => /repair|recovery/i.test(o.value));
                if (opt) catSel.value = opt.value;
            }
            setAudienceTab('All');
        }
        applyFilters();
    }

    function sortTable(field) {
        if (sortField === field) {
            sortAsc = !sortAsc;
        } else {
            sortField = field;
            sortAsc = true;
        }
        applyFilters();
    }

    function resetColumnFilters(apply = true) {
        if (document.getElementById('tool-select')) document.getElementById('tool-select').value = 'All';
        if (document.getElementById('env-select')) document.getElementById('env-select').value = 'All';
        if (document.getElementById('group-select')) document.getElementById('group-select').value = 'All';
        if (document.getElementById('audience-select')) document.getElementById('audience-select').value = 'All';
        if (document.getElementById('admin-select')) document.getElementById('admin-select').value = 'All';
        if (document.getElementById('noexit-select')) document.getElementById('noexit-select').value = 'All';
        if (document.getElementById('category-select')) document.getElementById('category-select').value = 'All';
        if (document.getElementById('desc-filter')) document.getElementById('desc-filter').value = '';
        if (document.getElementById('header-subsystem-select')) document.getElementById('header-subsystem-select').value = 'All';
        currentAudience = 'All';
        if (apply) applyFilters();
    }

    function resetFilters() {
        sessionStorage.clear();
        searchFilter = '';
        if (window.history && window.history.replaceState) {
            window.history.replaceState({}, document.title, window.location.pathname);
        }
        if (document.getElementById('search-input')) document.getElementById('search-input').value = '';
        isSourceMode = false;
        isFilteringShowTools = false;
        isShowToolsButtonOn = false;
        isManualShowToolsFilter = false;
        isFilteringInternal = false;
        currentAudience = 'All';

        const btnShow = document.getElementById('btn-show-tools-filter');
        if (btnShow) {
            btnShow.classList.remove('active');
            btnShow.style.background = '';
            btnShow.style.color = '';
            btnShow.innerHTML = '<span style="font-size: 16px; line-height: 1;">📊</span> ShowTools';
        }

        const btnInt = document.getElementById('btn-internal-filter');
        if (btnInt) {
            btnInt.classList.remove('active');
            btnInt.style.background = '';
            btnInt.style.color = '';
            btnInt.innerHTML = '<span style="font-size: 16px; line-height: 1;">🔒</span> Intern';
        }

        const headerGrp = document.getElementById('header-subsystem-select');
        if (headerGrp) headerGrp.value = 'All';

        const presetSelect = document.getElementById('filter-presets-select');
        if (presetSelect) presetSelect.value = '';

        updateViewModeUI();
        resetColumnFilters(false);
        document.querySelectorAll('.metric-card').forEach(c => c.classList.remove('active'));
        const cAll = document.getElementById('card-all'); if (cAll) cAll.classList.add('active');
        setAudienceTab('All');
    }

    // Parameter Persistence & Clear Logic
    function getParamStorageKey(toolName, paramName) {
        const baseStem = toolName.replace(/\.[^/.]+$/, "");
        return 'lcm_param_' + baseStem.toLowerCase() + '_' + paramName.toLowerCase();
    }

    function clearSingleParam(toolName, paramName) {
        const key = getParamStorageKey(toolName, paramName);
        localStorage.removeItem(key);
        
        const input = document.getElementById('param-input-' + paramName);
        if (input) {
            input.value = '';
        }
        recalculateCommandLine();
    }

    function clearAllParamsForTool() {
        if (!activeRunningTool || !activeRunningTool.Parameters) return;
        
        activeRunningTool.Parameters.forEach(p => {
            const key = getParamStorageKey(activeRunningTool.Name, p.Name);
            localStorage.removeItem(key);
            const input = document.getElementById('param-input-' + p.Name);
            if (input) {
                input.value = '';
            }
        });
        recalculateCommandLine();
        showToast('Cleared all parameters for ' + activeRunningTool.Name);
    }

    function showParamHelp(paramName) {
        if (!activeRunningTool) return;
        const params = activeRunningTool.Parameters || [];
        const param = params.find(p => p.Name.toLowerCase() === paramName.toLowerCase());
        const bodyEl = document.getElementById('run-help-param-body');
        if (!bodyEl) return;

        if (param) {
            bodyEl.innerHTML = '<strong style="color: var(--accent);">-' + param.Name + '</strong> ' +
                '<span style="color: var(--text-secondary);">(' + param.Type + (param.Mandatory ? ', Mandatory' : ', Optional') + ')</span><br>' +
                '<div style="margin-top: 4px;">' + (param.Description || 'No description provided.') + '</div>' +
                (param.Default ? '<div style="margin-top: 4px; font-size: 11px; color: var(--text-secondary);">Default: <code>' + param.Default + '</code></div>' : '');
        } else {
            bodyEl.innerHTML = activeRunningTool.Description || 'Focus or hover on any parameter on the left to inspect its complete description.';
        }
    }

    function initDraggableHelpModal() {
        const header = document.getElementById('help-modal-header');
        const card = document.getElementById('help-modal-card');
        if (!header || !card || card.__draggable_init) return;
        card.__draggable_init = true;

        let isDragging = false;
        let startX, startY, initialLeft, initialTop;

        header.addEventListener('mousedown', (e) => {
            if (e.target.tagName === 'BUTTON' || e.target.closest('button')) return;
            isDragging = true;
            header.style.cursor = 'grabbing';
            startX = e.clientX;
            startY = e.clientY;

            const rect = card.getBoundingClientRect();
            card.style.position = 'fixed';
            card.style.margin = '0';
            card.style.left = rect.left + 'px';
            card.style.top = rect.top + 'px';
            initialLeft = rect.left;
            initialTop = rect.top;

            const onMouseMove = (moveEvent) => {
                if (!isDragging) return;
                const dx = moveEvent.clientX - startX;
                const dy = moveEvent.clientY - startY;
                card.style.left = Math.max(10, Math.min(window.innerWidth - 120, initialLeft + dx)) + 'px';
                card.style.top = Math.max(10, Math.min(window.innerHeight - 120, initialTop + dy)) + 'px';
            };

            const onMouseUp = () => {
                isDragging = false;
                header.style.cursor = 'grab';
                document.removeEventListener('mousemove', onMouseMove);
                document.removeEventListener('mouseup', onMouseUp);
            };

            document.addEventListener('mousemove', onMouseMove);
            document.addEventListener('mouseup', onMouseUp);
        });
    }

    function openHelpModal() {
        const modal = document.getElementById('help-modal-overlay');
        if (modal) {
            modal.style.display = 'flex';
            initDraggableHelpModal();
        }
    }

    function closeHelpModal(e) {
        if (!e || e === true || e.target.id === 'help-modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-action') || e.target.classList.contains('btn-reset')) {
            const modal = document.getElementById('help-modal-overlay');
            if (modal) modal.style.display = 'none';
        }
    }

    function openRunDialog(idx) {
        activeRunningTool = toolsData[idx];
        const shortName = activeRunningTool.ShortName || activeRunningTool.Name.replace(/\.[^/.]+$/, "");
        document.getElementById('run-modal-title').innerText = '▶ ' + shortName + ' (' + activeRunningTool.Name + ')';
        document.getElementById('run-modal-desc').innerText = activeRunningTool.Description || 'No description available.';
        
        const paramContainer = document.getElementById('run-param-container');
        const paramFieldsList = document.getElementById('run-param-fields-list');
        const helpAllParamsList = document.getElementById('run-help-all-params-list');
        const helpExampleBox = document.getElementById('run-help-example-box');
        
        paramFieldsList.innerHTML = '';
        if (helpExampleBox) helpExampleBox.innerText = resolveToolExecutionCommand(activeRunningTool, isSourceMode);

        const params = activeRunningTool.Parameters || [];
        if (params.length > 0) {
            paramContainer.style.display = 'block';

            paramFieldsList.innerHTML = params.map(p => {
                const storageKey = getParamStorageKey(activeRunningTool.Name, p.Name);
                const isSwitch = p.Type.toLowerCase().includes('switch') || p.Type.toLowerCase().includes('bool');
                const savedVal = localStorage.getItem(storageKey) || p.Default || '';
                const isMandatory = p.Mandatory ? '<span style="color: var(--danger); font-weight: 700;">*</span>' : '';
                
                if (isSwitch) {
                    const isChecked = savedVal === 'true' || savedVal === '1' || savedVal === true || String(savedVal).toLowerCase() === 'true';
                    return '<div class="param-field" style="margin-bottom: 12px; background: rgba(255,255,255,0.03); padding: 8px 12px; border-radius: 6px; border: 1px solid var(--border);">' +
                        '<div style="display: flex; justify-content: space-between; align-items: center;">' +
                            '<label style="display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">' +
                                '<input type="checkbox" class="tool-param-switch" id="param-input-' + p.Name + '" ' + (isChecked ? 'checked' : '') + ' onchange="window.LcmTools.recalculateCommandLine()" onfocus="window.LcmTools.showParamHelp(\'' + p.Name + '\')" onmouseover="window.LcmTools.showParamHelp(\'' + p.Name + '\')" style="cursor: pointer; width: 16px; height: 16px;">' +
                                '<span class="param-name" style="font-weight: 600; color: var(--accent);">-' + p.Name + '</span> ' +
                                '<span style="font-size: 11px; color: var(--text-secondary);">(Switch Flag)</span>' +
                            '</label>' +
                            '<span style="font-size: 11px; color: var(--text-secondary);">' + (p.Description || '') + '</span>' +
                        '</div>' +
                    '</div>';
                }

                return '<div class="param-field" style="margin-bottom: 12px;">' +
                    '<div style="display: flex; justify-content: space-between; margin-bottom: 4px;">' +
                        '<div>' +
                            '<span class="param-name" style="font-weight: 600; color: var(--accent);">-' + p.Name + '</span>' + isMandatory + ' ' +
                            '<span style="font-size: 11px; color: var(--text-secondary);">(' + p.Type + ')</span>' +
                        '</div>' +
                        '<span style="font-size: 11px; color: var(--text-secondary);">' + (p.Description || '') + '</span>' +
                    '</div>' +
                    '<div class="input-clear-wrapper">' +
                        '<input type="text" class="tool-param-input" id="param-input-' + p.Name + '" value="' + savedVal + '" placeholder="Enter value for -' + p.Name + '..." oninput="window.LcmTools.recalculateCommandLine()" onfocus="window.LcmTools.showParamHelp(\'' + p.Name + '\')" onmouseover="window.LcmTools.showParamHelp(\'' + p.Name + '\')">' +
                        '<button class="btn-clear-param" onclick="window.LcmTools.clearSingleParam(\'' + activeRunningTool.Name + '\', \'' + p.Name + '\')" title="Clear this parameter">&times;</button>' +
                    '</div>' +
                '</div>';
            }).join('') +
            '<div style="display: flex; justify-content: flex-end; margin-top: 10px;">' +
                '<button class="btn-reset" onclick="window.LcmTools.clearAllParamsForTool()" style="font-size: 11px; padding: 4px 10px; color: var(--danger);">✕ Clear All Parameters</button>' +
            '</div>';

            if (helpAllParamsList) {
                helpAllParamsList.innerHTML = params.map(p => 
                    '<div style="margin-bottom: 6px; padding: 4px 0; border-bottom: 1px dashed rgba(255,255,255,0.08);">' +
                        '<strong style="color: var(--accent);">-' + p.Name + '</strong> ' +
                        '<span style="font-size: 11px; color: var(--text-secondary);">(' + p.Type + ')</span>: ' +
                        (p.Description || 'No description.') +
                    '</div>'
                ).join('');
            }
        } else {
            paramContainer.style.display = 'none';
            if (helpAllParamsList) {
                helpAllParamsList.innerHTML = '<div style="font-style: italic; color: var(--text-secondary);">This tool takes no explicit positional parameters or flags.</div>';
            }
        }

        showParamHelp('');
        recalculateCommandLine();
        document.getElementById('run-modal-overlay').style.display = 'flex';
    }

    function recalculateCommandLine() {
        if (!activeRunningTool) return;
        const params = activeRunningTool.Parameters || [];

        // Derive clean base command based on current view mode
        let baseCmd = resolveToolExecutionCommand(activeRunningTool, isSourceMode);
        const matchFile = baseCmd.match(/^(pwsh(?:\.exe)?\s+-File\s+"[^"]+"|\S+)/i);
        if (matchFile) {
            baseCmd = matchFile[0];
        } else if (baseCmd.includes(' -')) {
            baseCmd = baseCmd.substring(0, baseCmd.indexOf(' -')).trim();
        }

        let argParts = [];
        params.forEach(p => {
            const input = document.getElementById('param-input-' + p.Name);
            if (input) {
                const storageKey = getParamStorageKey(activeRunningTool.Name, p.Name);
                const isSwitch = p.Type.toLowerCase().includes('switch') || p.Type.toLowerCase().includes('bool');

                if (isSwitch) {
                    const isChecked = input.checked;
                    if (isChecked) {
                        localStorage.setItem(storageKey, 'true');
                        argParts.push('-' + p.Name);
                    } else {
                        localStorage.removeItem(storageKey);
                    }
                } else {
                    let val = input.value.trim();
                    if (val) {
                        localStorage.setItem(storageKey, val);
                        if (val.startsWith('-' + p.Name)) {
                            val = val.substring(p.Name.length + 1).trim();
                        }
                        if (val.startsWith('"') && val.endsWith('"')) {
                            val = val.slice(1, -1);
                        }
                        if (val) {
                            argParts.push('-' + p.Name + ' "' + val.replace(/"/g, '`"') + '"');
                        } else {
                            argParts.push('-' + p.Name);
                        }
                    } else {
                        localStorage.removeItem(storageKey);
                    }
                }
            }
        });

        let cmd = baseCmd;
        if (argParts.length > 0) {
            cmd = baseCmd + ' ' + argParts.join(' ');
        }

        const cmdInput = document.getElementById('run-cmd-input');
        if (cmdInput) {
            cmdInput.value = cmd;
        }
        validateRunCommand();
    }

    function validateRunCommand() {
        const valBox = document.getElementById('run-validation-error');
        const btnExec = document.getElementById('btn-run-execute');
        const cmd = document.getElementById('run-cmd-input').value.trim();
        document.getElementById('run-char-count').innerText = cmd.length + ' chars';

        const params = (activeRunningTool && activeRunningTool.Parameters) ? activeRunningTool.Parameters : [];
        let errorMsg = '';

        for (let p of params) {
            if (p.Mandatory) {
                const input = document.getElementById('param-input-' + p.Name);
                if (!input || !input.value.trim()) {
                    errorMsg = 'Mandatory parameter missing: -' + p.Name;
                    break;
                }
            }
        }

        if (errorMsg) {
            valBox.innerText = errorMsg;
            valBox.style.display = 'block';
            btnExec.disabled = true;
            btnExec.style.opacity = '0.5';
        } else {
            valBox.style.display = 'none';
            btnExec.disabled = false;
            btnExec.style.opacity = '1';
        }
    }

    function toggleExecutionDrawer(e) {
        if (e && e.stopPropagation) e.stopPropagation();
        const drawer = document.getElementById('executionFeedbackDrawer');
        const btn = document.getElementById('drawerToggleBtn');
        if (!drawer) return;
        const isCollapsed = drawer.classList.contains('collapsed');
        if (isCollapsed) {
            drawer.classList.remove('collapsed');
            drawer.classList.add('expanded');
            if (btn) btn.innerText = '▼ Collapse';
        } else {
            drawer.classList.remove('expanded');
            drawer.classList.add('collapsed');
            if (btn) btn.innerText = '▲ Expand';
        }
    }

    function showExecutionFeedback(target, exitCode, durationMs, stdout, stderr, isRunning = false) {
        const drawer = document.getElementById('executionFeedbackDrawer');
        const body = document.getElementById('executionFeedbackBody');
        const exitBadge = document.getElementById('drawerExitBadge');
        const targetBadge = document.getElementById('drawerTargetBadge');
        const durationBadge = document.getElementById('drawerDurationBadge');
        const btn = document.getElementById('drawerToggleBtn');
        if (!drawer || !body) return;

        if (targetBadge) targetBadge.innerText = target ? `[${target}]` : '';
        if (durationBadge) durationBadge.innerText = durationMs ? `${durationMs} ms` : '';

        if (isRunning) {
            if (exitBadge) {
                exitBadge.className = 'drawer-badge badge-running';
                exitBadge.innerText = '⏳ Running...';
            }
            body.innerText = `Dispatching execution for ${target}...`;
            return;
        }

        const isSuccess = (exitCode === 0);
        if (exitBadge) {
            if (exitCode !== undefined && exitCode !== null) {
                exitBadge.className = `drawer-badge ${isSuccess ? 'badge-success' : 'badge-error'}`;
                exitBadge.innerText = isSuccess ? '🟢 Exit 0' : `🔴 Exit ${exitCode}`;
            } else {
                exitBadge.className = 'drawer-badge badge-neutral';
                exitBadge.innerText = 'Completed';
            }
        }

        let text = '';
        if (stdout) text += stdout;
        if (stderr) {
            if (text) text += '\n--- STDERR ---\n';
            text += stderr;
        }
        if (!text) {
            text = isSuccess ? '(Command exited with code 0 and produced no stdout output)' : '(Command failed with no output)';
        }
        body.innerText = text;

        if (!isSuccess || (stderr && String(stderr).trim().length > 0)) {
            drawer.classList.remove('collapsed');
            drawer.classList.add('expanded');
            if (btn) btn.innerText = '▼ Collapse';
        }
    }

    function copyDrawerOutput() {
        const body = document.getElementById('executionFeedbackBody');
        if (body && body.innerText) {
            navigator.clipboard.writeText(body.innerText).then(() => {
                showToast('📋 Terminal output copied!');
            }).catch(() => {});
        }
    }

    function clearDrawerOutput() {
        const body = document.getElementById('executionFeedbackBody');
        const exitBadge = document.getElementById('drawerExitBadge');
        const targetBadge = document.getElementById('drawerTargetBadge');
        const durationBadge = document.getElementById('drawerDurationBadge');
        if (body) body.innerText = 'Ready. Executed actions, tests, and tool commands stream output here.';
        if (exitBadge) {
            exitBadge.className = 'drawer-badge badge-neutral';
            exitBadge.innerText = 'Ready';
        }
        if (targetBadge) targetBadge.innerText = '';
        if (durationBadge) durationBadge.innerText = '';
    }

    function getCollectedParamsDict(tool) {
        const params = (tool && tool.Parameters) ? tool.Parameters : [];
        const dict = {};
        params.forEach(p => {
            const input = document.getElementById('param-input-' + p.Name);
            if (!input) return;
            const isSwitch = p.Type.toLowerCase().includes('switch') || p.Type.toLowerCase().includes('bool');
            if (isSwitch) {
                if (input.checked) dict[p.Name] = true;
            } else {
                const val = input.value.trim();
                if (val) dict[p.Name] = val;
            }
        });
        return dict;
    }

    function getSavedParamsDict(tool) {
        const params = (tool && tool.Parameters) ? tool.Parameters : [];
        const dict = {};
        params.forEach(p => {
            const storageKey = getParamStorageKey(tool.Name, p.Name);
            const savedVal = localStorage.getItem(storageKey);
            if (savedVal !== null && savedVal !== undefined && savedVal !== '') {
                const isSwitch = p.Type.toLowerCase().includes('switch') || p.Type.toLowerCase().includes('bool');
                if (isSwitch) {
                    if (savedVal === 'true' || savedVal === '1' || savedVal === true) dict[p.Name] = true;
                } else {
                    let val = String(savedVal).trim();
                    if (val.startsWith('-' + p.Name)) {
                        val = val.substring(p.Name.length + 1).trim();
                    }
                    if (val.startsWith('"') && val.endsWith('"')) {
                        val = val.slice(1, -1);
                    }
                    if (val) dict[p.Name] = val;
                }
            }
        });
        return dict;
    }

    function executeConfiguredTool() {
        if (!activeRunningTool) return;
        const targetName = activeRunningTool.ShortName || activeRunningTool.Name;
        const paramsDict = getCollectedParamsDict(activeRunningTool);
        
        showToast('⚡ Dispatching ' + targetName + '...');
        showExecutionFeedback(targetName, null, 0, '', '', true);
        fetch(DAEMON_URL + '/api/action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'DO',
                target: targetName,
                parameters: paramsDict,
                caller: 'WebUI',
                options: {
                    sync: true,
                    noExit: isToolNoExit(activeRunningTool)
                }
            })
        }).then(r => r.json()).then(data => {
            const durMs = data.durationMs || 0;
            const exitCd = data.exitCode !== undefined ? data.exitCode : (data.status === 'ERROR' ? 1 : 0);
            showExecutionFeedback(targetName, exitCd, durMs, data.stdout, data.stderr || data.error);
            if (data.error || (data.exitCode !== undefined && data.exitCode !== 0)) {
                showToast('⚠️ Execution failed (' + (data.exitCode !== undefined ? 'Exit ' + data.exitCode : data.error) + ')');
            } else {
                showToast('✓ Dispatched: ' + targetName);
            }
        }).catch(err => {
            showExecutionFeedback(targetName, -1, 0, '', 'Daemon connection failed: ' + err.message);
            showToast('⚠️ Connection error to Daemon on Port 9876');
        });

        closeRunModal();
    }

    function closeRunModal(e) {
        if (!e || e === true || e.target.id === 'run-modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-reset')) {
            document.getElementById('run-modal-overlay').style.display = 'none';
            activeRunningTool = null;
        }
    }

    function getDispatcherCommand(tool) {
        const elevatedFlag = tool.Admin ? ' -Elevated' : '';
        return 'pwsh -File "D:\\Git_Repositories\\LCM_Inventory\\tools\\internal\\Invoke-InteractiveDesktop.ps1" -Command "' + tool.Example.replace(/"/g, '\\"') + '"' + elevatedFlag;
    }

    function dispatchLcmProtocol(uri) {
        let runner = document.getElementById('lcm-runner-frame');
        if (!runner) {
            runner = document.createElement('iframe');
            runner.id = 'lcm-runner-frame';
            runner.style.display = 'none';
            document.body.appendChild(runner);
        }
        runner.src = uri;
    }

    function isToolNoExit(tool) {
        return Boolean(tool && (tool.NoExit === true || tool.NoExit === 'true' || tool.NoExit === 1));
    }

    function hasMandatoryUnfilledParams(tool) {
        if (!tool || !tool.Parameters || tool.Parameters.length === 0) return false;
        return tool.Parameters.some(p => {
            if (!p.Mandatory) return false;
            const storageKey = getParamStorageKey(tool.Name, p.Name);
            const savedVal = localStorage.getItem(storageKey);
            const val = (savedVal !== null && savedVal !== undefined && savedVal !== '') ? savedVal : p.Default;
            return val === null || val === undefined || String(val).trim() === '';
        });
    }

    function runToolSmart(idx) {
        const tool = toolsData[idx];
        if (!tool) return;
        if (isToolBlocked(tool)) {
            showToast('⚠️ Execution Blocked: ' + (tool.ShortName || tool.Name) + ' has pending modifications. Finalize or Revert first.');
            return;
        }
        if (hasMandatoryUnfilledParams(tool)) {
            openRunDialog(idx);
        } else {
            runTool(idx);
        }
    }

    function openToolHelp(tool) {
        if (!tool) return;
        const relPath = tool.RelativePath || ('tools/' + tool.Name);
        showToast('❓ Opening Help in Notepad for ' + (tool.ShortName || tool.Name) + '...');
        
        fetch(DAEMON_URL + '/tool_help', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                relativePath: relPath,
                filePath: relPath
            })
        }).then(r => r.json()).then(data => {
            if (data.error) {
                fallbackToolHelp(tool, relPath);
            } else {
                showToast('✓ Opened help in Notepad (' + (data.helpFile ? data.helpFile.split(/[\\/]/).pop() : 'help.txt') + ')');
            }
        }).catch(() => {
            fallbackToolHelp(tool, relPath);
        });
    }

    function fallbackToolHelp(tool, relPath) {
        const toolStem = (tool.ShortName || tool.Name).replace(/\.[^/.]+$/, "");
        const fallbackCmd = 'pwsh.exe -NoProfile -ExecutionPolicy Bypass -Command "$ws = \'D:\\Git_Repositories\'; $p = Join-Path $ws (\'LCM_Inventory\\scratch\\help_' + toolStem + '.txt\'); $h = & (Join-Path $ws \'' + relPath + '\') -h 2>&1 | Out-String; Set-Content -LiteralPath $p -Value $h -Encoding UTF8; Start-Process notepad.exe -ArgumentList $p"';
        fetch(DAEMON_URL + '/execute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                command: fallbackCmd,
                elevated: false,
                noExit: false,
                windowStyle: 'Hidden'
            })
        }).then(() => {
            showToast('✓ Dispatched help to Notepad');
        }).catch(() => {
            const masterIdx = toolsData.findIndex(t => t.Name === tool.Name);
            if (masterIdx >= 0) openDetails(masterIdx);
        });
    }

    function buildToolCommandWithSavedParams(tool) {
        let baseCmd = resolveToolExecutionCommand(tool, isSourceMode);
        const matchFile = baseCmd.match(/^(pwsh(?:\.exe)?\s+-File\s+"[^"]+"|\S+)/i);
        if (matchFile) {
            baseCmd = matchFile[0];
        } else if (baseCmd.includes(' -')) {
            baseCmd = baseCmd.substring(0, baseCmd.indexOf(' -')).trim();
        }

        const params = tool.Parameters || [];
        let argParts = [];
        params.forEach(p => {
            const storageKey = getParamStorageKey(tool.Name, p.Name);
            const savedVal = localStorage.getItem(storageKey);
            if (savedVal !== null && savedVal !== undefined && savedVal !== '') {
                const isSwitch = p.Type.toLowerCase().includes('switch') || p.Type.toLowerCase().includes('bool');
                if (isSwitch) {
                    if (savedVal === 'true' || savedVal === '1' || savedVal === true) {
                        argParts.push('-' + p.Name);
                    }
                } else {
                    let val = String(savedVal).trim();
                    if (val.startsWith('-' + p.Name)) {
                        val = val.substring(p.Name.length + 1).trim();
                    }
                    if (val.startsWith('"') && val.endsWith('"')) {
                        val = val.slice(1, -1);
                    }
                    if (val) {
                        argParts.push('-' + p.Name + ' "' + val.replace(/"/g, '`"') + '"');
                    }
                }
            }
        });

        if (argParts.length > 0) {
            return baseCmd + ' ' + argParts.join(' ');
        }
        return baseCmd;
    }

    function runTool(idx) {
        const tool = toolsData[idx];
        if (!tool) return;
        const targetName = tool.ShortName || tool.Name;
        const savedParams = getSavedParamsDict(tool);
        
        showToast('⚡ Launching ' + (isSourceMode ? tool.Name : targetName) + '...');
        showExecutionFeedback(targetName, null, 0, '', '', true);
        fetch(DAEMON_URL + '/api/action', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                action: 'DO',
                target: targetName,
                parameters: savedParams,
                caller: 'WebUI',
                options: {
                    sync: true,
                    noExit: isToolNoExit(tool)
                }
            })
        }).then(r => r.json()).then(data => {
            const durMs = data.durationMs || 0;
            const exitCd = data.exitCode !== undefined ? data.exitCode : (data.status === 'ERROR' ? 1 : 0);
            showExecutionFeedback(targetName, exitCd, durMs, data.stdout, data.stderr || data.error);
            if (data.error || (data.exitCode !== undefined && data.exitCode !== 0)) {
                showToast('⚠️ Launch failed (' + (data.exitCode !== undefined ? 'Exit ' + data.exitCode : data.error) + ')');
            } else {
                showToast('✓ Completed: ' + (isSourceMode ? tool.Name : targetName));
            }
        }).catch(err => {
            showExecutionFeedback(targetName, -1, 0, '', 'Daemon connection failed: ' + err.message);
            showToast('⚠️ Connection error to Daemon on Port 9876');
        });
    }

    function copyCommand(cmd) {
        try { navigator.clipboard.writeText(cmd); } catch(e) {}
        showToast('📋 Command copied to clipboard!');
    }

    function showToast(msg) {
        const toast = document.getElementById('toast');
        if (!toast) return;
        toast.innerText = msg;
        toast.style.display = 'block';
        setTimeout(() => { toast.style.display = 'none'; }, 2800);
    }

    function openDetails(idx) {
        activeModalTool = toolsData[idx];
        const shortName = activeModalTool.ShortName || activeModalTool.Name.replace(/\.[^/.]+$/, "");
        document.getElementById('modal-title').innerText = shortName + ' (' + activeModalTool.Name + ')';
        document.getElementById('modal-example').innerText = activeModalTool.Example;
        document.getElementById('modal-dispatch-cmd').innerText = getDispatcherCommand(activeModalTool);
        document.getElementById('modal-path').innerText = (activeModalTool.RelativePath || activeModalTool.Name) + ' (' + activeModalTool.Group + ')';
        document.getElementById('modal-role-cat').innerText = (activeModalTool.Category || 'General') + ' • ' + activeModalTool.Audience + ' • Admin: ' + (activeModalTool.Admin ? 'Required' : 'No') + ' • NoExit: ' + (activeModalTool.NoExit ? '🔴 Yes (Keep Open)' : '🟢 No (Auto-Exit)');
        document.getElementById('modal-desc').innerText = activeModalTool.Description || 'No detailed description available.';
        
        // Render AST Dependencies
        const depsContainer = document.getElementById('modal-deps');
        if (depsContainer) {
            const deps = activeModalTool.Dependencies || [];
            if (deps.length > 0) {
                depsContainer.innerHTML = deps.map(d => '<span class="dep-pill">' + d + '</span>').join('');
            } else {
                depsContainer.innerHTML = '<span style="color: var(--text-secondary); font-style: italic;">No external dependencies detected.</span>';
            }
        }

        document.getElementById('modal-overlay').style.display = 'flex';
    }

    function closeModal(e) {
        if (!e || e === true || e.target.id === 'modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-reset')) {
            document.getElementById('modal-overlay').style.display = 'none';
        }
    }

    function runModalTool() {
        if (activeModalTool) {
            const idx = toolsData.findIndex(t => t.Name === activeModalTool.Name);
            if (idx >= 0) runTool(idx);
        }
    }

    function copyModalCommand() {
        if (activeModalTool) {
            copyCommand(activeModalTool.Example);
        }
    }

    /* In-Place Cell Editor */
    function openCellEditor(idx, field, event) {
        event.stopPropagation();
        activeEditCell = { idx: idx, field: field };
        const tool = toolsData[idx];
        const popover = document.getElementById('cell-editor');
        const container = document.getElementById('editor-control-container');

        let controlHtml = '';
        if (field === 'SubSystem' || field === 'Subsystem' || field === 'Group') {
            const curGroup = tool.SubSystem || tool.Subsystem || tool.Domain || tool.Group || 'General';
            const opts = (window.__LCM_OPTIONS__ && (window.__LCM_OPTIONS__.SubSystems || window.__LCM_OPTIONS__.Subsystems)) || Array.from(new Set(toolsData.map(t => t.SubSystem || t.Subsystem || t.Domain || t.Group).filter(Boolean)));
            const allGroups = Array.from(new Set(opts));
            if (!allGroups.includes('Needed?')) allGroups.push('Needed?');
            allGroups.sort();
            controlHtml = '<label style="font-size: 11px; color: var(--text-secondary); font-weight: 600;">Edit SubSystem:</label>' +
                '<select id="inline-edit-input" onchange="window.LcmTools.handleCellEditSelectChange(\'Subsystems\', this)">' +
                allGroups.map(g => '<option value="' + g + '" ' + (g === curGroup ? 'selected' : '') + '>' + g + '</option>').join('') +
                '<option value="__NEW__" style="color: #58a6ff; font-weight: 700;">+ New...</option>' +
                '</select>';
        } else if (field === 'Audience') {
            controlHtml = '<label style="font-size: 11px; color: var(--text-secondary); font-weight: 600;">Edit Audience:</label>' +
                '<select id="inline-edit-input">' +
                '<option value="User" ' + (tool.Audience === 'User' ? 'selected' : '') + '>User (Operator)</option>' +
                '<option value="Developer" ' + (tool.Audience === 'Developer' ? 'selected' : '') + '>Developer (Plumbing)</option>' +
                '</select>';
        } else if (field === 'Admin') {
            controlHtml = '<label style="font-size: 11px; color: var(--text-secondary); font-weight: 600;">ADMINMODE Design Criterion:</label>' +
                '<select id="inline-edit-input">' +
                '<option value="true" ' + (tool.Admin ? 'selected' : '') + '>🛡️ Elevation required by design</option>' +
                '<option value="false" ' + (!tool.Admin ? 'selected' : '') + '>👤 Elevation no longer required by redesign</option>' +
                '</select>';
        } else if (field === 'Category') {
            const curCat = tool.Category || 'General';
            const opts = (window.__LCM_OPTIONS__ && window.__LCM_OPTIONS__.Categories) || Array.from(new Set(toolsData.map(t => t.Category).filter(Boolean)));
            const allCats = Array.from(new Set(opts));
            allCats.sort();
            controlHtml = '<label style="font-size: 11px; color: var(--text-secondary); font-weight: 600;">Edit Category:</label>' +
                '<select id="inline-edit-input" onchange="window.LcmTools.handleCellEditSelectChange(\'Categories\', this)">' +
                allCats.map(c => '<option value="' + c + '" ' + (c === curCat ? 'selected' : '') + '>' + c + '</option>').join('') +
                '<option value="__NEW__" style="color: #58a6ff; font-weight: 700;">+ New...</option>' +
                '</select>';
        } else if (field === 'Description') {
            if (!isAutoSyncEnabled()) {
                showToast('❌ Auto-Sync is off. Description edits are disabled.');
                return;
            }
            controlHtml = '<label style="font-size: 11px; color: var(--text-secondary); font-weight: 600;">Edit Description:</label>' +
                '<textarea id="inline-edit-input" style="width: 100%; min-height: 80px; font-family: inherit; font-size: 12px; background: var(--bg-primary); color: var(--text-primary); border: 1px solid var(--border); border-radius: 4px; padding: 6px; resize: vertical; box-sizing: border-box;">' + (tool.Description || '') + '</textarea>';
        } else if (field === 'ShortName') {
            controlHtml = '<label style="font-size: 11px; color: var(--text-secondary); font-weight: 600;">Edit Short-Name Alias:</label>' +
                '<input type="text" id="inline-edit-input" value="' + (tool.ShortName || '') + '">';
        }

        container.innerHTML = controlHtml;
        popover.style.display = 'flex';
        popover.style.top = (event.pageY + 10) + 'px';
        popover.style.left = Math.min(event.pageX, window.innerWidth - 220) + 'px';
    }

    function saveCellEdit() {
        if (!activeEditCell) return;
        const input = document.getElementById('inline-edit-input');
        const val = input.value;
        const targetTool = toolsData[activeEditCell.idx];
        if (!targetTool) return;
        const baseStem = targetTool.Name.replace(/\.[^/.]+$/, "");
        const parsedVal = activeEditCell.field === 'Admin' ? (val === 'true') : val;

        let stored = {};
        try { stored = JSON.parse(localStorage.getItem('lcm_tools_overrides') || '{}'); } catch(e) {}

        const oldVal = targetTool[activeEditCell.field];
        targetTool[activeEditCell.field] = parsedVal;
        if (activeEditCell.field === 'SubSystem' || activeEditCell.field === 'Group' || activeEditCell.field === 'Domain' || activeEditCell.field === 'Subsystem') {
            targetTool.SubSystem = parsedVal;
            targetTool.Subsystem = parsedVal;
            targetTool.Group = parsedVal;
            targetTool.Domain = parsedVal;
        }
        targetTool._edited = true;
        
        const relKey = targetTool.RelativePath || targetTool.Name;
        if (!stored[relKey]) stored[relKey] = {};
        stored[relKey][activeEditCell.field] = parsedVal;
        stored[targetTool.Name] = stored[targetTool.Name] || {};
        stored[targetTool.Name][activeEditCell.field] = parsedVal;

        if (activeEditCell.field === 'SubSystem' || activeEditCell.field === 'Group' || activeEditCell.field === 'Domain' || activeEditCell.field === 'Subsystem') {
            stored[relKey].SubSystem = parsedVal;
            stored[relKey].Group = parsedVal;
            stored[relKey].Domain = parsedVal;
            stored[relKey].Subsystem = parsedVal;
            stored[targetTool.Name].SubSystem = parsedVal;
            stored[targetTool.Name].Group = parsedVal;
            stored[targetTool.Name].Domain = parsedVal;
            stored[targetTool.Name].Subsystem = parsedVal;
        }

        const pendingOld = (activeEditCell.field === 'SubSystem' || activeEditCell.field === 'Group' || activeEditCell.field === 'Domain' || activeEditCell.field === 'Subsystem')
            ? { SubSystem: targetTool.SubSystem, Group: oldVal, Domain: targetTool.Domain, Subsystem: targetTool.Subsystem }
            : { [activeEditCell.field]: oldVal };
        const pendingNew = (activeEditCell.field === 'SubSystem' || activeEditCell.field === 'Group' || activeEditCell.field === 'Domain' || activeEditCell.field === 'Subsystem')
            ? { SubSystem: parsedVal, Group: parsedVal, Domain: parsedVal, Subsystem: parsedVal }
            : { [activeEditCell.field]: parsedVal };

        markToolPending(targetTool, 'edit', pendingOld, pendingNew);

        localStorage.setItem('lcm_tools_overrides', JSON.stringify(stored));

        // Immediate sync to backend daemon
        const payload = JSON.stringify({
            type: 'tool_catalog_overrides',
            timestamp: new Date().toISOString(),
            overrides: stored
        });
        fetch(DAEMON_URL + '/sync_json', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: payload
        }).catch(() => {});

        if (syncChannel) {
            syncChannel.postMessage({ type: 'CATALOG_UPDATED', timestamp: Date.now() });
        }

        closeCellEditor();
        applyFilters();
        const editSummary = activeEditCell.field === 'Admin'
            ? ('ADMINMODE staged as ' + (parsedVal ? 'elevation required' : 'elevation no longer required by redesign'))
            : ('Staged ' + activeEditCell.field);
        showToast('✓ ' + editSummary + ' for ' + (targetTool.ShortName || baseStem) + ' (Blocked pending Finalize/Revert)');
    }

    function closeCellEditor() {
        const popover = document.getElementById('cell-editor');
        if (popover) popover.style.display = 'none';
        activeEditCell = null;
    }

    // -------------------------------------------------------------------------
    // Tool Modification Blockade & Two-State Resolution (Revert vs. Finalize)
    // -------------------------------------------------------------------------
    function getPendingModifications() {
        try {
            return JSON.parse(localStorage.getItem('lcm_pending_modifications') || '{}');
        } catch (e) {
            return {};
        }
    }

    function setPendingModifications(modMap) {
        localStorage.setItem('lcm_pending_modifications', JSON.stringify(modMap));
    }

    function isToolBlocked(tool) {
        if (!tool) return false;
        const mods = getPendingModifications();
        const relKey = tool.RelativePath || tool.Name;
        return Boolean(mods[relKey] || mods[tool.Name] || tool._isPendingModification || tool.IsBlocked);
    }

    function getToolPendingInfo(tool) {
        if (!tool) return null;
        const mods = getPendingModifications();
        const relKey = tool.RelativePath || tool.Name;
        const mod = mods[relKey] || mods[tool.Name];
        if (mod) return mod;
        if (tool._isPendingModification) {
            return { type: tool._pendingType || 'edit' };
        }
        return null;
    }

    function markToolPending(tool, type, oldState, newState) {
        if (!tool) return;
        const mods = getPendingModifications();
        const relKey = tool.RelativePath || tool.Name;
        const payload = {
            type: type, // 'edit' | 'rename' | 'delete'
            timestamp: new Date().toISOString(),
            oldState: oldState || {},
            newState: newState || {}
        };
        mods[relKey] = payload;
        mods[tool.Name] = payload;
        setPendingModifications(mods);
        tool._isPendingModification = true;
        tool._pendingType = type;
        tool.IsBlocked = true;
    }

    function initPendingModifications() {
        const mods = getPendingModifications();
        toolsData.forEach(t => {
            const relKey = t.RelativePath || t.Name;
            const mod = mods[relKey] || mods[t.Name];
            if (mod) {
                t._isPendingModification = true;
                t._pendingType = mod.type || 'edit';
                t.IsBlocked = true;
            } else {
                t._isPendingModification = false;
                t.IsBlocked = false;
                t._pendingType = null;
            }
        });
    }

    function revertTool(idx) {
        const tool = toolsData[idx];
        if (!tool) return;
        const mods = getPendingModifications();
        const relKey = tool.RelativePath || tool.Name;
        const modInfo = mods[relKey] || mods[tool.Name];
        if (modInfo && modInfo.oldState) {
            Object.assign(tool, modInfo.oldState);
        }
        delete mods[tool.Name];
        if (tool.RelativePath) delete mods[tool.RelativePath];
        const baseStem = tool.Name.replace(/\.[^/.]+$/, "");
        delete mods[baseStem];
        setPendingModifications(mods);

        // Remove from overrides
        let storedOverrides = {};
        try { storedOverrides = JSON.parse(localStorage.getItem('lcm_tools_overrides') || '{}'); } catch(e) {}
        delete storedOverrides[tool.Name];
        if (tool.RelativePath) delete storedOverrides[tool.RelativePath];
        delete storedOverrides[baseStem];
        localStorage.setItem('lcm_tools_overrides', JSON.stringify(storedOverrides));

        // Clear in-memory blockade across all matching tools in toolsData
        toolsData.forEach(t => {
            if (t === tool || (t.RelativePath && tool.RelativePath && t.RelativePath === tool.RelativePath) || t.Name === tool.Name) {
                t._isPendingModification = false;
                t._edited = false;
                t.IsBlocked = false;
                t._pendingType = null;
                if (modInfo && modInfo.oldState) {
                    Object.assign(t, modInfo.oldState);
                }
            }
        });

        // Sync to daemon
        fetch(DAEMON_URL + '/sync_json', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                type: 'tool_catalog_overrides',
                timestamp: new Date().toISOString(),
                overrides: storedOverrides
            })
        }).catch(() => {});

        applyFilters();
        showToast('✓ Reverted changes for ' + (tool.ShortName || tool.Name) + '. Execution blockade lifted.');
    }

    function finalizeTool(idx) {
        const tool = toolsData[idx];
        if (!tool) return;
        const mods = getPendingModifications();
        delete mods[tool.Name];
        if (tool.RelativePath) delete mods[tool.RelativePath];
        const baseStem = tool.Name.replace(/\.[^/.]+$/, "");
        delete mods[baseStem];
        setPendingModifications(mods);

        // Clear in-memory blockade across all matching tools in toolsData
        toolsData.forEach(t => {
            if (t === tool || (t.RelativePath && tool.RelativePath && t.RelativePath === tool.RelativePath) || t.Name === tool.Name) {
                t._isPendingModification = false;
                t.IsBlocked = false;
                t._pendingType = null;
            }
        });

        let storedOverrides = {};
        try { storedOverrides = JSON.parse(localStorage.getItem('lcm_tools_overrides') || '{}'); } catch(e) {}

        fetch(DAEMON_URL + '/sync_json', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                type: 'tool_catalog_overrides',
                timestamp: new Date().toISOString(),
                overrides: storedOverrides
            })
        }).catch(() => {});

        applyFilters();
        showToast('✓ Finalized changes for ' + (tool.ShortName || tool.Name) + '. Blockade lifted.');
    }

    function finalizeAllBlocked() {
        const blockedTools = toolsData.filter(t => t.IsBlocked || t._isPendingModification);
        if (blockedTools.length === 0) {
            showToast('ℹ️ No tools are currently blocked.');
            return;
        }
        const count = blockedTools.length;
        const mods = getPendingModifications();

        let storedOverrides = {};
        try { storedOverrides = JSON.parse(localStorage.getItem('lcm_tools_overrides') || '{}'); } catch(e) {}

        blockedTools.forEach(t => {
            const relKey = t.RelativePath || t.Name;
            const modInfo = mods[relKey] || mods[t.Name];
            if (modInfo && modInfo.newState) {
                storedOverrides[relKey] = storedOverrides[relKey] || {};
                Object.assign(storedOverrides[relKey], modInfo.newState);
                storedOverrides[t.Name] = storedOverrides[t.Name] || {};
                Object.assign(storedOverrides[t.Name], modInfo.newState);
                if (modInfo.newState.Group || modInfo.newState.Subsystem || modInfo.newState.Domain) {
                    const gVal = modInfo.newState.Subsystem || modInfo.newState.Group || modInfo.newState.Domain;
                    storedOverrides[relKey].Group = gVal;
                    storedOverrides[relKey].Domain = gVal;
                    storedOverrides[relKey].Subsystem = gVal;
                    storedOverrides[t.Name].Group = gVal;
                    storedOverrides[t.Name].Domain = gVal;
                    storedOverrides[t.Name].Subsystem = gVal;
                    t.Group = gVal;
                    t.Domain = gVal;
                    t.Subsystem = gVal;
                }
            }
            delete mods[t.Name];
            if (t.RelativePath) delete mods[t.RelativePath];
            const baseStem = t.Name.replace(/\.[^/.]+$/, "");
            delete mods[baseStem];
            t._isPendingModification = false;
            t.IsBlocked = false;
            t._pendingType = null;
        });

        setPendingModifications(mods);
        localStorage.setItem('lcm_tools_overrides', JSON.stringify(storedOverrides));

        fetch(DAEMON_URL + '/sync_json', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                type: 'tool_catalog_overrides',
                timestamp: new Date().toISOString(),
                overrides: storedOverrides
            })
        }).catch(() => {});

        applyFilters();
        showToast('✓ Finalized ' + count + ' blocked tool(s). All blockades lifted.');
    }

    function handleSelectFilterChange(field, selectEl) {
        if (!selectEl) return;
        if (selectEl.value === '__NEW__') {
            const promptName = field === 'Subsystems' ? 'Subsystem' : (field === 'Roles' ? 'Role' : 'Category');
            const newVal = prompt('Enter new ' + promptName + ' name:');
            if (!newVal || !newVal.trim()) {
                selectEl.value = 'All';
                applyFilters();
                return;
            }
            const cleanVal = newVal.trim();
            if (!window.__LCM_OPTIONS__) window.__LCM_OPTIONS__ = {};
            if (!window.__LCM_OPTIONS__[field]) window.__LCM_OPTIONS__[field] = [];
            if (!window.__LCM_OPTIONS__[field].includes(cleanVal)) {
                window.__LCM_OPTIONS__[field].push(cleanVal);
                window.__LCM_OPTIONS__[field].sort();
            }

            // Sync to daemon
            fetch(DAEMON_URL + '/add_explorer_option', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ field: field, value: cleanVal })
            }).catch(() => {});

            // Insert new option before __NEW__ and select it
            const newOpt = document.createElement('option');
            newOpt.value = cleanVal;
            newOpt.text = cleanVal;
            newOpt.selected = true;
            selectEl.insertBefore(newOpt, selectEl.lastElementChild);

            showToast('✓ Added new ' + promptName + ': ' + cleanVal);
        }
        applyFilters();
    }

    function handleCellEditSelectChange(field, selectEl) {
        if (!selectEl) return;
        if (selectEl.value === '__NEW__') {
            const promptName = field === 'Subsystems' ? 'Subsystem' : (field === 'Roles' ? 'Role' : 'Category');
            const newVal = prompt('Enter new ' + promptName + ' name:');
            if (!newVal || !newVal.trim()) {
                selectEl.selectedIndex = 0;
                return;
            }
            const cleanVal = newVal.trim();
            if (!window.__LCM_OPTIONS__) window.__LCM_OPTIONS__ = {};
            if (!window.__LCM_OPTIONS__[field]) window.__LCM_OPTIONS__[field] = [];
            if (!window.__LCM_OPTIONS__[field].includes(cleanVal)) {
                window.__LCM_OPTIONS__[field].push(cleanVal);
                window.__LCM_OPTIONS__[field].sort();
            }

            // Sync to daemon
            fetch(DAEMON_URL + '/add_explorer_option', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ field: field, value: cleanVal })
            }).catch(() => {});

            // Insert new option before __NEW__ and select it
            const newOpt = document.createElement('option');
            newOpt.value = cleanVal;
            newOpt.text = cleanVal;
            newOpt.selected = true;
            selectEl.insertBefore(newOpt, selectEl.lastElementChild);

            // Also update the corresponding table column filter dropdown
            const filterId = field === 'Subsystems' ? 'group-select' : 'category-select';
            const filterEl = document.getElementById(filterId);
            if (filterEl) {
                const optCopy = document.createElement('option');
                optCopy.value = cleanVal;
                optCopy.text = cleanVal;
                filterEl.insertBefore(optCopy, filterEl.lastElementChild);
            }
        }
    }

    // ShowTools & Internal Filters per CRP-182
    function updateShowToolsButtonUI() {
        const btn = document.getElementById('btn-show-tools-filter');
        const presetSelect = document.getElementById('filter-presets-select');
        if (btn) {
            btn.innerHTML = '<span style="font-size: 16px; line-height: 1;">📊</span> ShowTools';
            if (isShowToolsButtonOn) {
                btn.classList.add('active');
                btn.style.background = '#238636';
                btn.style.color = '#ffffff';
                if (presetSelect && isManualShowToolsFilter) presetSelect.value = 'preset_show_tools';
            } else {
                btn.classList.remove('active');
                btn.style.background = '';
                btn.style.color = '';
                if (presetSelect && presetSelect.value === 'preset_show_tools') presetSelect.value = '';
            }
        }
    }

    function toggleShowFilter() {
        if (isShowToolsButtonOn) {
            // User toggled it OFF
            isShowToolsButtonOn = false;
            isManualShowToolsFilter = false;
            sessionStorage.setItem('lcm_tools_show_filter', '0');
            sessionStorage.setItem('lcm_tools_manual_show', '0');
            updateShowToolsButtonUI();
            applyFilters();
            showToast('↺ Restored all tools view');
        } else {
            // User toggled it ON manually
            isShowToolsButtonOn = true;
            isManualShowToolsFilter = true;
            sessionStorage.setItem('lcm_tools_show_filter', '1');
            sessionStorage.setItem('lcm_tools_manual_show', '1');
            updateShowToolsButtonUI();
            applyFilters();
            showToast('📊 Filtered to ShowTools standard displays');
        }
    }

    function toggleInternalFilter() {
        isFilteringInternal = !isFilteringInternal;
        sessionStorage.setItem('lcm_tools_internal_filter', isFilteringInternal ? '1' : '0');
        updateInternalFilterUI();
        applyFilters();
        showToast(isFilteringInternal ? '🔒 Internal tools included in view' : '🔓 Internal tools excluded');
    }

    function updateInternalFilterUI() {
        const btn = document.getElementById('btn-internal-filter');
        if (btn) {
            btn.innerHTML = '<span style="font-size: 16px; line-height: 1;">🔒</span> Intern';
            if (isFilteringInternal) {
                btn.classList.add('active');
                btn.style.background = '#8957e5';
                btn.style.color = '#ffffff';
                btn.title = 'Internal tools are currently included in view. Click to exclude.';
            } else {
                btn.classList.remove('active');
                btn.style.background = '';
                btn.style.color = '';
                btn.title = 'Internal tools are excluded. Click to include Internal tools.';
            }
        }
    }

    // Mass Column Edit / Bulk Assignment Modal Functions
    function openMassEditModal() {
        const modal = document.getElementById('mass-edit-modal-overlay');
        const countEl = document.getElementById('mass-edit-count');
        if (!modal) return;
        if (!currentFilteredTools || currentFilteredTools.length === 0) {
            showToast('⚠️ No tools match current filter.');
            return;
        }
        if (countEl) countEl.innerText = currentFilteredTools.length;
        updateMassEditOptions();
        toggleMassEditMode();
        modal.style.display = 'flex';
    }

    function closeMassEditModal(e) {
        if (!e || e === true || e.target.id === 'mass-edit-modal-overlay' || e.target.classList.contains('modal-close') || e.target.classList.contains('btn-reset')) {
            const modal = document.getElementById('mass-edit-modal-overlay');
            if (modal) modal.style.display = 'none';
        }
    }

    function toggleMassEditMode() {
        const mode = document.querySelector('input[name="mass-edit-mode"]:checked')?.value || 'set';
        const setCont = document.getElementById('mass-edit-set-container');
        const repCont = document.getElementById('mass-edit-replace-container');
        if (setCont) setCont.style.display = mode === 'set' ? 'block' : 'none';
        if (repCont) repCont.style.display = mode === 'replace' ? 'block' : 'none';
    }

    function updateMassEditOptions() {
        const col = document.getElementById('mass-edit-col')?.value || 'SubSystem';
        const select = document.getElementById('mass-edit-val-select');
        const customInput = document.getElementById('mass-edit-val-custom');
        if (!select) return;
        if (customInput) customInput.style.display = 'none';

        let options = [];
        if (col === 'SubSystem' || col === 'Group') {
            options = (window.__LCM_OPTIONS__ && (window.__LCM_OPTIONS__.SubSystems || window.__LCM_OPTIONS__.Subsystems)) || Array.from(new Set(toolsData.map(t => t.SubSystem || t.Subsystem || t.Group || t.Domain).filter(Boolean)));
        } else if (col === 'Category') {
            options = (window.__LCM_OPTIONS__ && window.__LCM_OPTIONS__.Categories) || Array.from(new Set(toolsData.map(t => t.Category).filter(Boolean)));
        } else if (col === 'Audience') {
            options = ['User', 'Developer', 'Internal'];
        }
        options = Array.from(new Set(options)).sort();

        select.innerHTML = options.map(o => '<option value="' + escapeHtml(o) + '">' + escapeHtml(o) + '</option>').join('') +
            '<option value="__CUSTOM__" style="color: #58a6ff; font-weight: 700;">+ Custom Value...</option>';
    }

    function handleMassEditSelectChange(sel) {
        const customInput = document.getElementById('mass-edit-val-custom');
        if (customInput) {
            if (sel.value === '__CUSTOM__') {
                customInput.style.display = 'block';
                customInput.focus();
            } else {
                customInput.style.display = 'none';
            }
        }
    }

    function executeMassEdit() {
        if (!currentFilteredTools || currentFilteredTools.length === 0) return;
        const col = document.getElementById('mass-edit-col')?.value || 'Group';
        const mode = document.querySelector('input[name="mass-edit-mode"]:checked')?.value || 'set';
        let targetVal = '';

        if (mode === 'set') {
            const sel = document.getElementById('mass-edit-val-select');
            const custom = document.getElementById('mass-edit-val-custom');
            if (sel.value === '__CUSTOM__') {
                targetVal = (custom.value || '').trim();
            } else {
                targetVal = sel.value;
            }
            if (!targetVal) {
                alert('Please specify a value to set.');
                return;
            }
        } else {
            const findText = (document.getElementById('mass-edit-find')?.value || '').trim();
            if (!findText) {
                alert('Please enter a pattern to match.');
                return;
            }
        }

        let stored = {};
        try { stored = JSON.parse(localStorage.getItem('lcm_tools_overrides') || '{}'); } catch(e) {}
        let updatedCount = 0;

        const findPattern = (document.getElementById('mass-edit-find')?.value || '').trim();
        const repPattern = (document.getElementById('mass-edit-replace')?.value || '').trim();
        let regex = null;
        if (mode === 'replace') {
            const escaped = findPattern.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.');
            regex = new RegExp(escaped, 'i');
        }

        currentFilteredTools.forEach(t => {
            let oldVal = t[col] || '';
            let newVal = '';
            if (mode === 'set') {
                newVal = targetVal;
            } else {
                if (!regex.test(oldVal)) return;
                newVal = oldVal.replace(regex, repPattern);
            }

            t[col] = newVal;
            if (col === 'SubSystem' || col === 'Group') {
                t.SubSystem = newVal;
                t.Subsystem = newVal;
                t.Group = newVal;
                t.Domain = newVal;
            }
            t._edited = true;

            const relKey = t.RelativePath || t.Name;
            stored[relKey] = stored[relKey] || {};
            stored[relKey][col] = newVal;
            stored[t.Name] = stored[t.Name] || {};
            stored[t.Name][col] = newVal;
            if (col === 'SubSystem' || col === 'Group') {
                stored[relKey].SubSystem = newVal;
                stored[relKey].Subsystem = newVal;
                stored[relKey].Group = newVal;
                stored[relKey].Domain = newVal;
                stored[t.Name].SubSystem = newVal;
                stored[t.Name].Subsystem = newVal;
                stored[t.Name].Group = newVal;
                stored[t.Name].Domain = newVal;
            }
            updatedCount++;
        });

        localStorage.setItem('lcm_tools_overrides', JSON.stringify(stored));
        fetch(DAEMON_URL + '/sync_json', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                type: 'tool_catalog_overrides',
                timestamp: new Date().toISOString(),
                overrides: stored
            })
        }).catch(() => {});

        closeMassEditModal(true);
        applyFilters();
        showToast('✓ Bulk updated ' + updatedCount + ' tool(s) [' + col + '].');
    }

    // Compatibility stubs
    function isAutoSyncEnabled() { return true; }
    function toggleAutoSync() {}
    function exportOverrides() { showToast('Direct daemon sync active. Overrides exported automatically.'); }

    async function refreshToolCatalog() {
        if (!window.LcmDisplay || typeof window.LcmDisplay.refresh !== 'function') {
            showToast('Display refresh is unavailable; the current snapshot is retained.');
            return;
        }
        showToast('🔄 Requesting a published tool catalog revision...');
        return window.LcmDisplay.refresh();
    }

    function closeAllModals() {
        closeModal(true);
        closeHelpModal(true);
        closeRunModal(true);
        closeRenameModal(true);
        closeCleanupModal(true);
        closeActionMenu();
        closeCellEditor();
    }

    window.addEventListener('keydown', (e) => {
        if (e.key === 'F5' || e.code === 'F5') {
            e.preventDefault();
            refreshToolCatalog();
        } else if (e.key === 'Escape') {
            closeAllModals();
        }
    });

    // -------------------------------------------------------------------------
    // Filter Presets Engine & Navigation
    // -------------------------------------------------------------------------
    const STANDARD_PRESETS = {
        'preset_default': {
            name: '⭐ Default View',
            audience: 'User',
            group: 'All',
            env: 'All',
            role: 'All',
            admin: 'All',
            noexit: 'All',
            cat: 'All',
            search: ''
        },
        'preset_lcm_core': {
            name: '🏛️ LCM Core',
            audience: 'All',
            group: 'LCM',
            env: 'All',
            role: 'All',
            admin: 'All',
            noexit: 'All',
            cat: 'All',
            search: ''
        },
        'preset_general': {
            name: '🔧 General Tools (Not LCM)',
            audience: 'All',
            group: 'All',
            env: 'All',
            role: 'All',
            admin: 'All',
            noexit: 'All',
            cat: 'All',
            search: '!group:LCM'
        },
        'preset_no_sub_cmd': {
            name: '🚫 Exclude Subsystems & CMD',
            audience: 'All',
            group: 'All',
            env: 'All',
            role: 'All',
            admin: 'All',
            noexit: 'All',
            cat: 'All',
            search: '!group:HaSSD06 !env:CMD'
        },
        'preset_show_tools': {
            name: '📊 ShowTools',
            audience: 'All',
            group: 'All',
            env: 'All',
            role: 'All',
            admin: 'All',
            noexit: 'All',
            cat: 'All',
            search: ''
        },
        'preset_none': {
            name: '⚪ None (Clear All)',
            audience: 'All',
            group: 'All',
            env: 'All',
            role: 'All',
            admin: 'All',
            noexit: 'All',
            cat: 'All',
            search: ''
        }
    };

    function loadCustomPresets() {
        try {
            return JSON.parse(localStorage.getItem('lcm_tool_filter_presets') || '{}');
        } catch (e) {
            return {};
        }
    }

    function saveCustomPresets(presets) {
        localStorage.setItem('lcm_tool_filter_presets', JSON.stringify(presets));
        renderPresetOptions();
    }

    function renderPresetOptions() {
        const customGroup = document.getElementById('custom-presets-group');
        if (!customGroup) return;
        const customPresets = loadCustomPresets();
        customGroup.innerHTML = Object.keys(customPresets).map(id => {
            return '<option value="' + id + '">' + (customPresets[id].name || id) + '</option>';
        }).join('');
    }

    function applyPreset(presetId) {
        if (!presetId) return;
        const standard = STANDARD_PRESETS[presetId];
        const custom = standard ? null : loadCustomPresets()[presetId];
        const preset = standard || custom;
        if (!preset) return;

        resetColumnFilters(false);
        if (preset.audience) setAudienceTab(preset.audience);
        if (preset.group) {
            const el = document.getElementById('group-select');
            if (el) el.value = preset.group;
        }
        if (preset.env) {
            const el = document.getElementById('env-select');
            if (el) el.value = preset.env;
        }
        if (preset.admin) {
            const el = document.getElementById('admin-select');
            if (el) el.value = preset.admin;
        }
        if (preset.noexit) {
            const el = document.getElementById('noexit-select');
            if (el) el.value = preset.noexit;
        }
        if (preset.cat) {
            const el = document.getElementById('category-select');
            if (el) el.value = preset.cat;
        }
        const searchInput = document.getElementById('search-input');
        if (searchInput) searchInput.value = preset.search || '';

        // Synchronize ShowTools button highlight state
        const btnShow = document.getElementById('btn-show-tools-filter');
        if (presetId === 'preset_show_tools') {
            isFilteringShowTools = true;
            if (btnShow) {
                btnShow.classList.add('active');
                btnShow.style.background = 'var(--accent, #58a6ff)';
                btnShow.style.color = '#ffffff';
            }
        } else {
            isFilteringShowTools = false;
            if (btnShow) {
                btnShow.classList.remove('active');
                btnShow.style.background = '';
                btnShow.style.color = '';
            }
        }

        applyFilters();
        showToast('✓ Filter preset applied: ' + (preset.name || presetId));
    }

    function addCustomPreset() {
        const name = prompt('Enter a name for this custom filter preset:');
        if (!name || !name.trim()) return;
        const trimmedName = name.trim();
        const id = 'custom_' + Date.now();
        const presets = loadCustomPresets();
        
        presets[id] = {
            name: '📌 ' + trimmedName,
            audience: currentAudience,
            group: document.getElementById('group-select') ? document.getElementById('group-select').value : 'All',
            env: document.getElementById('env-select') ? document.getElementById('env-select').value : 'All',
            admin: document.getElementById('admin-select') ? document.getElementById('admin-select').value : 'All',
            noexit: document.getElementById('noexit-select') ? document.getElementById('noexit-select').value : 'All',
            cat: document.getElementById('category-select') ? document.getElementById('category-select').value : 'All',
            search: document.getElementById('search-input') ? document.getElementById('search-input').value : ''
        };
        saveCustomPresets(presets);
        const sel = document.getElementById('filter-presets-select');
        if (sel) sel.value = id;
        showToast('✓ Saved preset: ' + trimmedName);
    }

    function replaceCustomPreset() {
        const sel = document.getElementById('filter-presets-select');
        const selectedId = sel ? sel.value : '';
        if (!selectedId || !selectedId.startsWith('custom_')) {
            alert('Please select a custom preset from the dropdown first to replace it.');
            return;
        }
        const presets = loadCustomPresets();
        if (!presets[selectedId]) return;

        presets[selectedId].audience = currentAudience;
        presets[selectedId].group = document.getElementById('group-select') ? document.getElementById('group-select').value : 'All';
        presets[selectedId].env = document.getElementById('env-select') ? document.getElementById('env-select').value : 'All';
        presets[selectedId].admin = document.getElementById('admin-select') ? document.getElementById('admin-select').value : 'All';
        presets[selectedId].noexit = document.getElementById('noexit-select') ? document.getElementById('noexit-select').value : 'All';
        presets[selectedId].cat = document.getElementById('category-select') ? document.getElementById('category-select').value : 'All';
        presets[selectedId].search = document.getElementById('search-input') ? document.getElementById('search-input').value : '';

        saveCustomPresets(presets);
        showToast('✓ Replaced preset: ' + presets[selectedId].name);
    }

    function deleteCustomPreset() {
        const sel = document.getElementById('filter-presets-select');
        const selectedId = sel ? sel.value : '';
        if (!selectedId || !selectedId.startsWith('custom_')) {
            alert('Please select a custom preset to delete.');
            return;
        }
        const presets = loadCustomPresets();
        const name = presets[selectedId] ? presets[selectedId].name : selectedId;
        if (!confirm('Are you sure you want to delete the custom preset "' + name + '"?')) return;
        delete presets[selectedId];
        saveCustomPresets(presets);
        if (sel) sel.value = '';
        showToast('✓ Deleted preset: ' + name);
    }

    function goBack() {
        if (window.history.length > 1) {
            window.history.back();
        } else {
            window.location.href = '/inventory';
        }
    }

    function openToolIntents() {
        showToast('🎯 Opening Tool Intents Explorer...');
        if (window.location.protocol === 'file:') {
            window.location.href = 'SHOW_TOOL_INTENTS.html';
            return;
        }
        window.open('/tool_intents', '_blank');
    }

    function initTheme() {
        const savedTheme = localStorage.getItem('lcm_theme') || localStorage.getItem('lcm_theme_mode') || 'dark';
        applyTheme(savedTheme);
    }

    function applyTheme(theme) {
        if (theme === 'light') {
            document.body.classList.add('light-theme');
            document.documentElement.setAttribute('data-theme', 'light');
        } else {
            document.body.classList.remove('light-theme');
            document.documentElement.setAttribute('data-theme', 'dark');
        }
        localStorage.setItem('lcm_theme', theme);
        localStorage.setItem('lcm_theme_mode', theme);
    }

    function toggleTheme() {
        const isLight = document.body.classList.contains('light-theme');
        applyTheme(isLight ? 'dark' : 'light');
        showToast(isLight ? '🌓 Switched to Dark Theme' : '🌓 Switched to Light Theme');
    }

    function initApplication() {
        initTheme();
        loadAllShortNames();
        initPendingModifications();

        // Check if session has already been initialized in this browser window/tab
        const hasSession = sessionStorage.getItem('lcm_tools_session_active');
        if (!hasSession) {
            const initAud = (typeof currentAudience !== 'undefined' && currentAudience) ? currentAudience : 'All';
            const initGrp = (typeof currentGroup !== 'undefined' && currentGroup) ? currentGroup : 'All';

            sessionStorage.setItem('lcm_tools_session_active', '1');
            sessionStorage.setItem('lcm_tools_show_filter', '0');
            sessionStorage.setItem('lcm_tools_internal_filter', '0');
            sessionStorage.setItem('lcm_tools_audience', initAud);
            sessionStorage.setItem('lcm_tools_group', initGrp);
            sessionStorage.setItem('lcm_tools_sort_field', 'ShortName');
            sessionStorage.setItem('lcm_tools_sort_asc', 'true');
            
            isShowToolsButtonOn = false;
            isManualShowToolsFilter = false;
            isFilteringInternal = false;
            currentAudience = initAud;
            sortField = 'ShortName';
            sortAsc = true;
            isSourceMode = false;

            resetColumnFilters(false);
            if (document.getElementById('group-select')) document.getElementById('group-select').value = initGrp;
            if (document.getElementById('audience-select')) document.getElementById('audience-select').value = initAud;
            if (document.getElementById('header-subsystem-select')) document.getElementById('header-subsystem-select').value = initGrp;
        } else {
            // Window was refreshed: retain active filters without resetting
            const savedShowFilter = sessionStorage.getItem('lcm_tools_show_filter');
            isShowToolsButtonOn = savedShowFilter === '1';
            isManualShowToolsFilter = sessionStorage.getItem('lcm_tools_manual_show') === '1';

            const savedInternalFilter = sessionStorage.getItem('lcm_tools_internal_filter');
            isFilteringInternal = savedInternalFilter === '1';

            let savedAudience = sessionStorage.getItem('lcm_tools_audience') || currentAudience;
            if (savedAudience) currentAudience = savedAudience;

            let savedSortField = sessionStorage.getItem('lcm_tools_sort_field');
            if (savedSortField) sortField = savedSortField;
            let savedSortAsc = sessionStorage.getItem('lcm_tools_sort_asc');
            if (savedSortAsc != null) sortAsc = savedSortAsc === 'true';

            if (searchFilter && document.getElementById('search-input')) document.getElementById('search-input').value = searchFilter;
            if (currentTool && currentTool !== 'All' && document.getElementById('tool-select')) document.getElementById('tool-select').value = currentTool;
            if (currentEnv && currentEnv !== 'All' && document.getElementById('env-select')) document.getElementById('env-select').value = currentEnv;
            if (currentGroup && currentGroup !== 'All' && document.getElementById('group-select')) document.getElementById('group-select').value = currentGroup;
            if (currentAdmin && currentAdmin !== 'All' && document.getElementById('admin-select')) document.getElementById('admin-select').value = currentAdmin;
            let currentCat = sessionStorage.getItem('lcm_tools_category') || 'All';
            if (currentCat && currentCat !== 'All' && document.getElementById('category-select')) document.getElementById('category-select').value = currentCat;
            let currentNoExit = sessionStorage.getItem('lcm_tools_noexit') || 'All';
            if (currentNoExit && currentNoExit !== 'All' && document.getElementById('noexit-select')) document.getElementById('noexit-select').value = currentNoExit;
        }

        const queryOverrides = [
            ['Audience', 'audience-select', value => value === 'Dev' ? 'Developer' : value],
            ['Group', 'group-select'],
            ['Subsystem', 'group-select'],
            ['Tool', 'tool-select'],
            ['Env', 'env-select'],
            ['Filter', 'search-input']
        ];
        queryOverrides.forEach(([queryKey, elementId, normalize]) => {
            if (!requestedDisplayParams.has(queryKey)) return;
            const value = requestedDisplayParams.get(queryKey).slice(0, 300);
            const normalized = normalize ? normalize(value) : value;
            const element = document.getElementById(elementId);
            if (element) element.value = normalized;
            if (queryKey === 'Audience') currentAudience = normalized;
            else if (queryKey === 'Group' || queryKey === 'Subsystem') currentGroup = normalized;
            else if (queryKey === 'Tool') currentTool = normalized;
            else if (queryKey === 'Env') currentEnv = normalized;
            else if (queryKey === 'Filter') searchFilter = normalized;
        });

        // Initialize Print Preview Atom
        if (window.LcmTablePrintAtom) {
            window.LcmTablePrintAtom.init({
                documentTitle: 'LCM Tool Explorer',
                subsystem: 'LCM',
                tableSelector: 'table',
                tbodySelector: '#tools-tbody',
                getViewMode: () => {
                    return !isSourceMode ? 'Short-Names' : (currentAudience === 'All' ? 'All Tools' : currentAudience + ' Tools');
                },
                getFileName: () => {
                    return 'SHOW_TOOLS.html';
                },
                getDate: () => {
                    const stampEl = document.getElementById('catalog-timestamp');
                    return stampEl ? stampEl.innerText.replace(/^Generated:\s*/i, '').trim() : new Date().toISOString().replace('T', ' ').substring(0, 19);
                },
                getFilterSummary: () => {
                    const searchVal = document.getElementById('search-input') ? document.getElementById('search-input').value.trim() : '';
                    const groupVal = document.getElementById('group-select') ? document.getElementById('group-select').value : 'All';
                    let filterParts = [];
                    if (searchVal) filterParts.push('Search: "' + searchVal + '"');
                    if (groupVal !== 'All') filterParts.push('Group: ' + groupVal);
                    return filterParts.length > 0 ? filterParts.join(' • ') : 'All Items in View';
                }
            });
        }

        renderPresetOptions();
        updateViewModeUI();
        updateShowToolsButtonUI();
        updateInternalFilterUI();
        setAudienceTab(currentAudience || 'All');

        document.addEventListener('click', (e) => {
            if (!e.target.closest('#cell-editor') && !e.target.closest('.cell-editable')) {
                closeCellEditor();
            }
        });
    }

    // Expose methods to global scope
    window.LcmTools = {
        init: initApplication,
        applyFilters: applyFilters,
        setAudienceTab: setAudienceTab,
        filterByCard: filterByCard,
        filterBySubsystem: filterBySubsystem,
        sortTable: sortTable,
        resetColumnFilters: resetColumnFilters,
        resetFilters: resetFilters,
        applyPreset: applyPreset,
        addCustomPreset: addCustomPreset,
        replaceCustomPreset: replaceCustomPreset,
        deleteCustomPreset: deleteCustomPreset,
        goBack: goBack,
        openToolIntents: openToolIntents,
        openRunDialog: openRunDialog,
        recalculateCommandLine: recalculateCommandLine,
        validateRunCommand: validateRunCommand,
        executeConfiguredTool: executeConfiguredTool,
        closeRunModal: closeRunModal,
        runTool: runTool,
        runToolSmart: runToolSmart,
        openToolHelp: openToolHelp,
        revertTool: revertTool,
        finalizeTool: finalizeTool,
        finalizeAllBlocked: finalizeAllBlocked,
        handleSelectFilterChange: handleSelectFilterChange,
        handleCellEditSelectChange: handleCellEditSelectChange,
        toggleShowFilter: toggleShowFilter,
        toggleInternalFilter: toggleInternalFilter,
        copyCommand: copyCommand,
        openDetails: openDetails,
        closeModal: closeModal,
        closeAllModals: closeAllModals,
        runModalTool: runModalTool,
        copyModalCommand: copyModalCommand,
        openCellEditor: openCellEditor,
        saveCellEdit: saveCellEdit,
        closeCellEditor: closeCellEditor,
        toggleNoExit: toggleNoExit,
        toggleViewMode: toggleViewMode,
        openActionMenu: openActionMenu,
        closeActionMenu: closeActionMenu,
        menuAction: menuAction,
        openRenameModal: openRenameModal,
        closeRenameModal: closeRenameModal,
        executeRename: executeRename,
        addModalAlias: addModalAlias,
        removeModalAlias: removeModalAlias,
        openMassEditModal: openMassEditModal,
        closeMassEditModal: closeMassEditModal,
        toggleMassEditMode: toggleMassEditMode,
        updateMassEditOptions: updateMassEditOptions,
        handleMassEditSelectChange: handleMassEditSelectChange,
        executeMassEdit: executeMassEdit,
        deleteSpecificShortName: deleteSpecificShortName,
        loadAllShortNames: loadAllShortNames,
        openCleanupModal: openCleanupModal,
        closeCleanupModal: closeCleanupModal,
        executeCleanup: executeCleanup,
        exportOverrides: exportOverrides,
        refreshToolCatalog: refreshToolCatalog,
        toggleAutoSync: toggleAutoSync,
        isAutoSyncEnabled: isAutoSyncEnabled,
        openHelpModal: openHelpModal,
        closeHelpModal: closeHelpModal,
        showParamHelp: showParamHelp,
        clearSingleParam: clearSingleParam,
        clearAllParamsForTool: clearAllParamsForTool,
        toggleTheme: toggleTheme,
        toggleExecutionDrawer: toggleExecutionDrawer,
        showExecutionFeedback: showExecutionFeedback,
        copyDrawerOutput: copyDrawerOutput,
        clearDrawerOutput: clearDrawerOutput
    };

    window.LcmDisplayApply = async function(html) {
        const parsedDocument = new DOMParser().parseFromString(html, 'text/html');
        const payloadNode = parsedDocument.querySelector('script#lcm-display-data[type="application/json"]');
        if (!payloadNode) throw new Error('Published tools page has no JSON display payload.');
        const payload = JSON.parse(payloadNode.textContent);
        if (!Array.isArray(payload.tools)) throw new Error('Published tools payload is malformed.');

        baselineData = payload.tools;
        toolsData = JSON.parse(JSON.stringify(baselineData));
        window.__LCM_CONFIG__ = payload.config || {};
        window.__LCM_OPTIONS__ = payload.options || {};
        applyOverridesFromStorage();
        toolsData.forEach(tool => {
            const extMatch = tool.Name.match(/\.([a-zA-Z0-9]+)$/);
            tool.Env = extMatch ? extMatch[1].toUpperCase() : 'FILE';
            if (!tool.ShortName) tool.ShortName = tool.Name.replace(/\.[^/.]+$/, '');
            tool.SubSystem = tool.SubSystem || tool.Subsystem || tool.Group || tool.Domain || '';
        });
        applyFilters();
    };

    window.LcmDisplayCaptureState = function() {
        return {
            sourceMode: isSourceMode,
            sortField,
            sortAsc,
            audience: currentAudience,
            group: currentGroup
        };
    };

    window.LcmDisplayRestoreState = function(state) {
        if (!state || typeof state !== 'object') return;
        if (typeof state.sourceMode === 'boolean') isSourceMode = state.sourceMode;
        if (typeof state.sortField === 'string') sortField = state.sortField;
        if (typeof state.sortAsc === 'boolean') sortAsc = state.sortAsc;
        if (typeof state.audience === 'string') currentAudience = state.audience;
        if (typeof state.group === 'string') currentGroup = state.group;
        sessionStorage.setItem('lcm_tools_sourcemode', String(isSourceMode));
        sessionStorage.setItem('lcm_tools_sort_field', sortField);
        sessionStorage.setItem('lcm_tools_sort_asc', String(sortAsc));
        updateViewModeUI();
        applyFilters();
    };

    // Auto-init on DOMContentLoaded
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initApplication);
    } else {
        initApplication();
    }
})(window, document);
