/**
 * ==============================================================================
 * LCM UNIVERSAL TABLE & THEME ENGINE (v1.1.0)
 * Canonical shared UI/UX module for all LCM dashboards and viewers.
 * Conforms to CRP-2026-017, CRP-2026-018, CRP-2026-019, CRP-108, CRP-158.
 * ==============================================================================
 */

(function (window, document) {
    'use strict';

    const STORAGE_KEY_THEME = 'lcm_theme_mode';

    const LcmTableEngine = {
        version: '1.1.0',

        // --------------------------------------------------------------------------
        // 1. Theme Management (Light / Dark with High Contrast Persistence)
        // --------------------------------------------------------------------------
        initTheme: function () {
            const savedTheme = localStorage.getItem(STORAGE_KEY_THEME) || 'dark';
            this.setTheme(savedTheme);
        },

        setTheme: function (mode) {
            const isLight = (mode === 'light');
            if (isLight) {
                document.body.classList.add('light-theme');
                document.documentElement.setAttribute('data-theme', 'light');
            } else {
                document.body.classList.remove('light-theme');
                document.documentElement.setAttribute('data-theme', 'dark');
            }
            localStorage.setItem(STORAGE_KEY_THEME, isLight ? 'light' : 'dark');

            // Update any theme toggles on page
            const icon = document.getElementById('theme-icon');
            const label = document.getElementById('theme-label');
            if (icon) icon.textContent = isLight ? '🌙' : '☀️';
            if (label) label.textContent = isLight ? 'Dark Mode' : 'Light Mode';

            // Dispatch global event for custom component re-render
            window.dispatchEvent(new CustomEvent('lcm-theme-changed', { detail: { theme: isLight ? 'light' : 'dark' } }));
        },

        toggleTheme: function () {
            const isCurrentlyLight = document.body.classList.contains('light-theme');
            this.setTheme(isCurrentlyLight ? 'dark' : 'light');
        },

        // --------------------------------------------------------------------------
        // 2. Windows-Style Top-Right [⬅ Back] Navigation
        // --------------------------------------------------------------------------
        injectBackButton: function (targetElementId, fallbackUrl, label) {
            const target = document.getElementById(targetElementId);
            if (!target) return;

            // Avoid duplicate insertion
            if (document.getElementById('btn-lcm-back-nav')) return;

            const btn = document.createElement('button');
            btn.id = 'btn-lcm-back-nav';
            btn.className = 'btn-back-nav';
            btn.innerHTML = `<span>⬅️</span> <span>${label || 'Back'}</span>`;
            btn.title = 'Return to originating view (Windows-style Back)';
            btn.onclick = function () {
                if (window.opener || window.history.length > 1) {
                    window.history.back();
                } else if (fallbackUrl) {
                    window.location.href = fallbackUrl;
                }
            };

            target.appendChild(btn);
        },

        // --------------------------------------------------------------------------
        // 3. Row Selection & Batch Action Engine
        // --------------------------------------------------------------------------
        initCheckboxes: function (options) {
            const table = document.getElementById(options.tableId);
            const masterCheckbox = document.getElementById(options.masterCheckboxId);
            const batchBar = document.getElementById(options.batchBarId);
            const countDisplay = document.getElementById(options.selectedCountId);

            if (!table) return;

            function updateSelectionState() {
                const rowCheckboxes = table.querySelectorAll('tbody input.row-select-checkbox');
                const selected = Array.from(rowCheckboxes).filter(cb => cb.checked);
                const total = rowCheckboxes.length;

                if (masterCheckbox) {
                    masterCheckbox.checked = (total > 0 && selected.length === total);
                    masterCheckbox.indeterminate = (selected.length > 0 && selected.length < total);
                }

                if (batchBar) {
                    if (selected.length > 0) {
                        batchBar.style.display = 'flex';
                        if (countDisplay) countDisplay.textContent = `${selected.length} of ${total} selected`;
                    } else {
                        batchBar.style.display = 'none';
                    }
                }

                if (typeof options.onSelectionChange === 'function') {
                    options.onSelectionChange(selected.map(cb => cb.dataset.rowId || cb.value));
                }
            }

            if (masterCheckbox) {
                masterCheckbox.addEventListener('change', function () {
                    const rowCheckboxes = table.querySelectorAll('tbody input.row-select-checkbox');
                    rowCheckboxes.forEach(cb => {
                        // Only check rows that are currently visible (not display: none)
                        const tr = cb.closest('tr');
                        if (tr && tr.style.display !== 'none') {
                            cb.checked = masterCheckbox.checked;
                        }
                    });
                    updateSelectionState();
                });
            }

            table.addEventListener('change', function (e) {
                if (e.target && e.target.classList.contains('row-select-checkbox')) {
                    updateSelectionState();
                }
            });

            return {
                getSelectedIds: function () {
                    const rowCheckboxes = table.querySelectorAll('tbody input.row-select-checkbox:checked');
                    return Array.from(rowCheckboxes).map(cb => cb.dataset.rowId || cb.value);
                },
                clearSelection: function () {
                    table.querySelectorAll('tbody input.row-select-checkbox').forEach(cb => { cb.checked = false; });
                    updateSelectionState();
                }
            };
        },

        // --------------------------------------------------------------------------
        // 4. Universal Tokenized Search with Column Qualifiers & Negation (CRP-158)
        // --------------------------------------------------------------------------
        parseTokens: function (query) {
            if (!query || !query.trim()) return [];
            const raw = query.trim();
            const tokens = [];
            // Matches [!][field:](["']val["']|\S+) OR [!](["']val["']|\S+)
            const regex = /(!?)([a-zA-Z0-9_\-\.]+):(!?)(?:"([^"]*)"|'([^']*)'|(\S+))|(!?)(?:"([^"]*)"|'([^']*)'|(\S+))/g;
            let match;
            while ((match = regex.exec(raw)) !== null) {
                if (match[2] !== undefined) {
                    const isNeg1 = match[1] === '!';
                    const field = match[2].toLowerCase().trim();
                    const isNeg2 = match[3] === '!';
                    const val = (match[4] !== undefined ? match[4] : (match[5] !== undefined ? match[5] : match[6] || '')).toLowerCase().trim();
                    const negate = isNeg1 !== isNeg2;
                    tokens.push({
                        type: 'field',
                        field: field,
                        value: val,
                        negate: negate,
                        raw: match[0]
                    });
                } else {
                    const negate = match[7] === '!';
                    const val = (match[8] !== undefined ? match[8] : (match[9] !== undefined ? match[9] : match[10] || '')).toLowerCase().trim();
                    if (val) {
                        tokens.push({
                            type: 'general',
                            field: null,
                            value: val,
                            negate: negate,
                            raw: match[0]
                        });
                    }
                }
            }
            return tokens;
        },

        getColumnMap: function (table) {
            const colMap = {};
            if (!table) return colMap;
            const headers = table.querySelectorAll('thead tr:first-child th');
            headers.forEach((th, idx) => {
                const text = th.innerText.trim().toLowerCase();
                const dataCol = (th.dataset.col || '').toLowerCase();
                const thId = (th.id || '').replace(/^th-?/, '').toLowerCase();

                if (text) {
                    colMap[text] = idx;
                    text.split(/[\/\-_,\s]+/).forEach(part => {
                        const clean = part.trim();
                        if (clean.length > 1 && !colMap[clean]) colMap[clean] = idx;
                    });
                }
                if (dataCol) colMap[dataCol] = idx;
                if (thId && !colMap[thId]) colMap[thId] = idx;
            });
            return colMap;
        },

        matchesRow: function (tr, tokens, colMap, options = {}) {
            if (!tokens || tokens.length === 0) return true;
            const aliases = options.aliases || {
                repo: 'scope',
                origin: 'scope',
                subsystem: 'scope',
                status: 'state',
                prog: 'state',
                progress: 'state',
                plan: 'state',
                title: 'name',
                tool: 'name'
            };

            return tokens.every(tok => {
                let isMatch = false;
                if (tok.type === 'field') {
                    let colIdx = colMap[tok.field];
                    if (colIdx === undefined && aliases[tok.field]) {
                        colIdx = colMap[aliases[tok.field]];
                    }

                    if (colIdx !== undefined && tr.cells[colIdx]) {
                        const cell = tr.cells[colIdx];
                        const cellText = cell.innerText.toLowerCase();
                        const cellDataVal = (cell.dataset.value || '').toLowerCase();
                        isMatch = cellText.includes(tok.value) || cellDataVal.includes(tok.value);
                    } else if (tr.dataset[tok.field] !== undefined) {
                        isMatch = String(tr.dataset[tok.field]).toLowerCase().includes(tok.value);
                    } else {
                        isMatch = tr.innerText.toLowerCase().includes(tok.value);
                    }
                } else {
                    isMatch = tr.innerText.toLowerCase().includes(tok.value);
                }
                return tok.negate ? !isMatch : isMatch;
            });
        },

        matchesObject: function (obj, query, options = {}) {
            const tokens = Array.isArray(query) ? query : this.parseTokens(query);
            if (tokens.length === 0) return true;

            const aliases = options.aliases || {
                repo: ['origin_repo', 'repository', 'repo_name', 'scope'],
                scope: ['origin_repo', 'repository', 'scope', 'subsystem'],
                status: ['progress_state', 'state', 'status'],
                state: ['state', 'plan_state', 'progress_state', 'status'],
                plan: ['state', 'plan_state'],
                prog: ['progress_state', 'status'],
                prio: ['priority', 'prio', 'urgency'],
                id: ['id', 'crp_id', 'cr_id', 'bundle_id'],
                name: ['title', 'name', 'tool', 'tool_name']
            };

            return tokens.every(tok => {
                let isMatch = false;
                if (tok.type === 'field') {
                    const targetKeys = aliases[tok.field] || [tok.field];
                    for (const k of targetKeys) {
                        if (obj[k] !== undefined && obj[k] !== null) {
                            const valStr = String(obj[k]).toLowerCase();
                            if (valStr.includes(tok.value) || (tok.field === 'prio' && valStr === tok.value)) {
                                isMatch = true;
                                break;
                            }
                        }
                    }
                    if (!isMatch && obj[tok.field] !== undefined && obj[tok.field] !== null) {
                        isMatch = String(obj[tok.field]).toLowerCase().includes(tok.value);
                    }
                } else {
                    for (const k of Object.keys(obj)) {
                        if (typeof obj[k] === 'object' && obj[k] !== null) {
                            if (JSON.stringify(obj[k]).toLowerCase().includes(tok.value)) {
                                isMatch = true;
                                break;
                            }
                        } else if (obj[k] !== undefined && obj[k] !== null) {
                            if (String(obj[k]).toLowerCase().includes(tok.value)) {
                                isMatch = true;
                                break;
                            }
                        }
                    }
                }
                return tok.negate ? !isMatch : isMatch;
            });
        },

        matchesQuery: function (textToSearch, query) {
            if (!query || !query.trim()) return true;
            const tokens = this.parseTokens(query);
            const text = (textToSearch || '').toLowerCase();

            return tokens.every(tok => {
                const isMatch = text.includes(tok.value);
                return tok.negate ? !isMatch : isMatch;
            });
        },

        filterTable: function (options) {
            const table = document.getElementById(options.tableId);
            if (!table) return 0;
            const query = options.query !== undefined ? options.query : (document.getElementById(options.searchInputId) ? document.getElementById(options.searchInputId).value : '');
            const tokens = this.parseTokens(query);
            const colMap = this.getColumnMap(table);
            const rows = table.querySelectorAll('tbody tr');
            let visibleCount = 0;

            rows.forEach(tr => {
                const isVisible = this.matchesRow(tr, tokens, colMap, options);
                tr.style.display = isVisible ? '' : 'none';
                if (isVisible) visibleCount++;
            });

            if (options.counterId) {
                const counter = document.getElementById(options.counterId);
                if (counter) {
                    counter.textContent = `Showing ${visibleCount} of ${rows.length} items`;
                }
            }

            if (typeof options.onFilter === 'function') {
                options.onFilter(visibleCount, rows.length);
            }

            return visibleCount;
        },

        bindSearch: function (options) {
            const searchInput = document.getElementById(options.searchInputId);
            if (!searchInput) return;

            const runFilter = () => this.filterTable(options);

            searchInput.addEventListener('input', runFilter);
            searchInput.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    searchInput.value = '';
                    runFilter();
                }
            });

            // Initial filter run
            runFilter();
        },

        // --------------------------------------------------------------------------
        // 5. Multi-Column Alphanumeric / Date Sorting
        // --------------------------------------------------------------------------
        sortTable: function (tbody, columnIndex, direction, isNumeric) {
            const rows = Array.from(tbody.querySelectorAll('tr'));
            const mult = (direction === 'desc') ? -1 : 1;

            rows.sort((a, b) => {
                const cellA = a.children[columnIndex];
                const cellB = b.children[columnIndex];
                if (!cellA || !cellB) return 0;

                const textA = cellA.innerText.trim();
                const textB = cellB.innerText.trim();

                if (isNumeric) {
                    const numA = parseFloat(textA.replace(/[^0-9.-]/g, '')) || 0;
                    const numB = parseFloat(textB.replace(/[^0-9.-]/g, '')) || 0;
                    return (numA - numB) * mult;
                }

                return textA.localeCompare(textB, undefined, { numeric: true, sensitivity: 'base' }) * mult;
            });

            rows.forEach(row => tbody.appendChild(row));
        }
    };

    // Auto-init theme on load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => LcmTableEngine.initTheme());
    } else {
        LcmTableEngine.initTheme();
    }

    window.LcmTableEngine = LcmTableEngine;
})(window, document);
