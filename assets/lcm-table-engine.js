/**
 * ==============================================================================
 * LCM UNIVERSAL TABLE & THEME ENGINE (v1.0.0)
 * Canonical shared UI/UX module for all LCM dashboards and viewers.
 * Conforms to CRP-2026-017, CRP-2026-018, CRP-2026-019.
 * ==============================================================================
 */

(function (window, document) {
    'use strict';

    const STORAGE_KEY_THEME = 'lcm_theme_mode';

    const LcmTableEngine = {
        version: '1.0.0',

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
        // 4. Universal Search with !term Negation Engine
        // --------------------------------------------------------------------------
        matchesQuery: function (textToSearch, query) {
            if (!query || !query.trim()) return true;
            const text = (textToSearch || '').toLowerCase();
            const terms = query.toLowerCase().split(/\s+/).filter(t => t.length > 0);

            for (const term of terms) {
                if (term.startsWith('!')) {
                    const negTerm = term.slice(1);
                    if (negTerm.length > 0 && text.includes(negTerm)) {
                        return false; // Negation matched -> Exclude row
                    }
                } else {
                    if (!text.includes(term)) {
                        return false; // Positive term not found -> Exclude row
                    }
                }
            }
            return true;
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
