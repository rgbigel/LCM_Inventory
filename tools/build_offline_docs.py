"""
Module: tools/build_offline_docs.py
Purpose: Converts Markdown specifications and runbooks into standalone, beautifully styled HTML documents for offline travel reading.
Authors: Rolf, Workspace_AI Engine
Version: 10.2.0
Date: 2026-10-13
"""

import os
import re
import sys
import markdown

# Ensure UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

CSS_TEMPLATE = """
:root {
    --bg: #0d1117;
    --card-bg: #161b22;
    --card-border: #30363d;
    --text-main: #f0f6fc;
    --text-muted: #8b949e;
    --accent: #58a6ff;
    --accent-hover: #79c0ff;
    --code-bg: #1f242c;
    --table-header: #21262d;
    --table-stripe: #13171f;
    --success: #3fb950;
    --warning: #d29922;
    --danger: #f85149;
    --note-bg: rgba(56, 139, 253, 0.1);
    --note-border: #388bfd;
    --important-bg: rgba(163, 113, 247, 0.1);
    --important-border: #a371f7;
    --warning-bg: rgba(210, 153, 34, 0.1);
    --warning-border: #d29922;
}

@media (prefers-color-scheme: light) {
    /* Optional light mode variables if opened on mobile / default */
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    background-color: var(--bg);
    color: var(--text-main);
    line-height: 1.65;
    padding: 30px 20px;
}

.wrapper {
    max-width: 1080px;
    margin: 0 auto;
    background: var(--card-bg);
    border: 1px solid var(--card-border);
    border-radius: 14px;
    padding: 45px 50px;
    box-shadow: 0 12px 36px rgba(0, 0, 0, 0.5);
}

@media (max-width: 768px) {
    .wrapper {
        padding: 24px 18px;
    }
}

/* Header & Nav */
.doc-header-badge {
    display: inline-block;
    background: rgba(88, 166, 255, 0.15);
    color: var(--accent);
    padding: 4px 12px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 12px;
}

.doc-nav-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid var(--card-border);
    padding-bottom: 15px;
    margin-bottom: 30px;
}

.doc-nav-link {
    color: var(--accent);
    text-decoration: none;
    font-size: 14px;
    font-weight: 500;
}

.doc-nav-link:hover {
    text-decoration: underline;
}

/* Typography */
h1 {
    font-size: 28px;
    font-weight: 700;
    color: #ffffff;
    border-bottom: 1px solid var(--card-border);
    padding-bottom: 12px;
    margin-top: 10px;
    margin-bottom: 20px;
}

h2 {
    font-size: 22px;
    font-weight: 600;
    color: var(--accent);
    margin-top: 36px;
    margin-bottom: 16px;
    border-bottom: 1px solid rgba(48, 54, 61, 0.5);
    padding-bottom: 6px;
}

h3 {
    font-size: 18px;
    font-weight: 600;
    color: #e6edf3;
    margin-top: 24px;
    margin-bottom: 12px;
}

h4 {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-muted);
    margin-top: 18px;
    margin-bottom: 8px;
}

p {
    margin-bottom: 16px;
    color: #c9d1d9;
}

ul, ol {
    margin-bottom: 18px;
    padding-left: 28px;
    color: #c9d1d9;
}

li {
    margin-bottom: 6px;
}

hr {
    border: none;
    border-top: 1px solid var(--card-border);
    margin: 32px 0;
}

a {
    color: var(--accent);
    text-decoration: none;
}

a:hover {
    color: var(--accent-hover);
    text-decoration: underline;
}

/* Code & Syntax */
code {
    font-family: 'JetBrains Mono', 'Cascadia Code', Consolas, monospace;
    font-size: 13px;
    background: var(--code-bg);
    color: #79c0ff;
    padding: 2px 6px;
    border-radius: 6px;
    border: 1px solid rgba(110, 118, 129, 0.2);
}

pre {
    background: var(--code-bg);
    border: 1px solid var(--card-border);
    border-radius: 8px;
    padding: 16px;
    overflow-x: auto;
    margin-bottom: 20px;
}

pre code {
    background: none;
    border: none;
    padding: 0;
    font-size: 13px;
    color: #e6edf3;
}

/* Tables */
table {
    width: 100%;
    border-collapse: collapse;
    margin: 20px 0 28px 0;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid var(--card-border);
    font-size: 14px;
}

th {
    background: var(--table-header);
    color: #f0f6fc;
    font-weight: 600;
    text-align: left;
    padding: 12px 16px;
    border-bottom: 1px solid var(--card-border);
}

td {
    padding: 11px 16px;
    border-bottom: 1px solid rgba(48, 54, 61, 0.4);
    color: #c9d1d9;
}

tr:nth-child(even) {
    background: var(--table-stripe);
}

tr:hover {
    background: rgba(88, 166, 255, 0.05);
}

/* Alerts & Callouts */
blockquote {
    border-left: 4px solid var(--note-border);
    background: var(--note-bg);
    padding: 14px 18px;
    border-radius: 0 8px 8px 0;
    margin: 20px 0;
    color: #c9d1d9;
}

.alert-note {
    border-left: 4px solid var(--note-border);
    background: var(--note-bg);
    padding: 14px 18px;
    border-radius: 0 8px 8px 0;
    margin: 20px 0;
}

.alert-important {
    border-left: 4px solid var(--important-border);
    background: var(--important-bg);
    padding: 14px 18px;
    border-radius: 0 8px 8px 0;
    margin: 20px 0;
}

.alert-warning {
    border-left: 4px solid var(--warning-border);
    background: var(--warning-bg);
    padding: 14px 18px;
    border-radius: 0 8px 8px 0;
    margin: 20px 0;
}

/* Badges */
.badge {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 12px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
}

.badge-success { background: rgba(63, 185, 80, 0.15); color: var(--success); }
.badge-info { background: rgba(88, 166, 255, 0.15); color: var(--accent); }
.badge-warning { background: rgba(210, 153, 34, 0.15); color: var(--warning); }

/* Mermaid Diagram Containers */
.mermaid {
    background: #11151c;
    border: 1px solid var(--card-border);
    border-radius: 8px;
    padding: 20px;
    margin: 20px 0;
    text-align: center;
}

/* Print Styling */
@media print {
    body { background: #ffffff; color: #000000; }
    .wrapper { border: none; box-shadow: none; padding: 0; }
    th { background: #f0f0f0; color: #000000; }
    td { color: #222222; }
    code { background: #f4f4f4; color: #000000; }
}
"""

def preprocess_markdown(text: str) -> str:
    """Preprocess GitHub-specific markdown features like alerts."""
    # Transform GitHub Alert syntax [!NOTE], [!IMPORTANT], [!WARNING], [!TIP]
    def replace_alert(match):
        alert_type = match.group(1).upper()
        content = match.group(2)
        css_class = "alert-note"
        title = "Note"
        if alert_type == "IMPORTANT":
            css_class = "alert-important"
            title = "Important"
        elif alert_type in ("WARNING", "CAUTION"):
            css_class = "alert-warning"
            title = "Warning"
        elif alert_type == "TIP":
            css_class = "alert-note"
            title = "Tip"
        return f'<div class="{css_class}"><strong>{title}:</strong><br>{content}</div>'

    text = re.sub(
        r'>\s*\[!(NOTE|IMPORTANT|WARNING|CAUTION|TIP)\]\s*\n((?:>.*\n?)*)',
        lambda m: replace_alert_block(m.group(1), m.group(2)),
        text
    )
    return text

def replace_alert_block(alert_type: str, body: str) -> str:
    cleaned_lines = []
    for line in body.strip().split('\n'):
        cleaned_lines.append(re.sub(r'^>\s?', '', line))
    content = '<br>'.join(cleaned_lines)
    alert_type_up = alert_type.upper()
    css_class = "alert-note"
    icon = "ℹ️"
    if alert_type_up == "IMPORTANT":
        css_class = "alert-important"
        icon = "📌"
    elif alert_type_up in ("WARNING", "CAUTION"):
        css_class = "alert-warning"
        icon = "⚠️"
    elif alert_type_up == "TIP":
        css_class = "alert-note"
        icon = "💡"
    return f'\n<div class="{css_class}"><strong>{icon} {alert_type_up}:</strong><br>{content}</div>\n'

def convert_md_to_html(source_path: str, target_path: str, title: str, category: str):
    with open(source_path, 'r', encoding='utf-8') as f:
        raw_md = f.read()

    preprocessed_md = preprocess_markdown(raw_md)

    md_extensions = [
        'extra',
        'tables',
        'fenced_code',
        'codehilite',
        'toc',
        'sane_lists'
    ]

    html_body = markdown.markdown(preprocessed_md, extensions=md_extensions)

    # Wrap in complete standalone HTML page
    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - Offline Travel Document</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({{startOnLoad:true, theme: 'dark'}});</script>
    <style>
{CSS_TEMPLATE}
    </style>
</head>
<body>
    <div class="wrapper">
        <div class="doc-nav-bar">
            <div>
                <span class="doc-header-badge">{category}</span>
                <span style="color: var(--text-muted); font-size: 13px; margin-left: 10px;">Offline Reading Edition</span>
            </div>
            <div>
                <a href="index.html" class="doc-nav-link">← Back to Document Index</a>
            </div>
        </div>
        
        {html_body}

        <hr>
        <div style="text-align: center; color: var(--text-muted); font-size: 12px; margin-top: 20px;">
            LCM 10.0.0 Governance Architecture &bull; Generated for Offline Travel Reading on {os.path.basename(target_path)}
        </div>
    </div>
</body>
</html>
"""

    with open(target_path, 'w', encoding='utf-8') as f:
        f.write(full_html)
    print(f"  [OK] Rendered: {os.path.basename(target_path)}")

def build_index_portal(target_dir: str, title: str, subtitle: str, doc_list: list):
    cards_html = ""
    for d in doc_list:
        cards_html += f"""
        <div style="background: #161b22; border: 1px solid #30363d; border-radius: 10px; padding: 20px; margin-bottom: 16px; transition: transform 0.2s;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                <div>
                    <h3 style="margin-top: 0; font-size: 18px;"><a href="{d['filename']}" style="color: #58a6ff; text-decoration: none;">{d['title']}</a></h3>
                    <p style="color: #8b949e; font-size: 14px; margin-bottom: 8px;">{d['description']}</p>
                    <span style="font-size: 12px; color: #79c0ff; font-family: monospace;">{d['source']}</span>
                </div>
                <a href="{d['filename']}" style="background: #21262d; border: 1px solid #30363d; color: #f0f6fc; padding: 8px 16px; border-radius: 6px; text-decoration: none; font-size: 13px; font-weight: 600; white-space: nowrap; margin-left: 15px;">Read Document →</a>
            </div>
        </div>
        """

    index_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title} - Offline Document Index</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
{CSS_TEMPLATE}
    </style>
</head>
<body>
    <div class="wrapper">
        <div style="text-align: center; margin-bottom: 35px; border-bottom: 1px solid #30363d; padding-bottom: 25px;">
            <span class="doc-header-badge">Offline Travel Documentation Portal</span>
            <h1 style="border: none; margin-bottom: 8px;">{title}</h1>
            <p style="font-size: 15px; color: #8b949e;">{subtitle}</p>
        </div>

        {cards_html}

        <hr>
        <div style="text-align: center; color: var(--text-muted); font-size: 12px;">
            Lifecycle Model (LCM) Framework &bull; Full Offline Travel Reading Suite &bull; Date: 2026-10-13
        </div>
    </div>
</body>
</html>
"""
    index_path = os.path.join(target_dir, "index.html")
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write(index_html)
    print(f"  [OK] Generated Portal Index: {index_path}")

def main():
    lcm_dir = r"D:\OneDrive\Berchtware\Antigravity\LCM Documents"
    ha_dir = r"D:\OneDrive\Berchtware\Antigravity\HaSSD06 Documents"

    os.makedirs(lcm_dir, exist_ok=True)
    os.makedirs(ha_dir, exist_ok=True)

    print("\n=======================================================")
    print(" 1. Building LCM Offline Documentation Suite")
    print("=======================================================")

    lcm_docs = [
        {
            "src": r"D:\Git_Repositories\LCM_AI\README.md",
            "filename": "01_LCM_AI_README.html",
            "title": "LCM_AI Core Framework Overview",
            "description": "Baseline specification, architectural principles, and lifecycle operational overview.",
            "category": "Core Framework",
            "source": "LCM_AI/README.md"
        },
        {
            "src": r"D:\Git_Repositories\AGENTS.md",
            "filename": "02_AGENTS_Governance_Directive.html",
            "title": "LCM Multi-Repository Governance Directive",
            "description": "Comprehensive governance index, rule cross-reference table, and junction discovery architecture.",
            "category": "Governance Policy",
            "source": "AGENTS.md"
        },
        {
            "src": r"D:\Git_Repositories\LCM_AI\docs\Architecture.md",
            "filename": "03_LCM_Architecture_Specification.html",
            "title": "LCM Core Architecture Specification",
            "description": "Tripartite specification defining rule hubs, junction reparse points, and commit gating.",
            "category": "Core Architecture",
            "source": "LCM_AI/docs/Architecture.md"
        },
        {
            "src": r"D:\Git_Repositories\LCM_AI\docs\Requirements.md",
            "filename": "04_LCM_Requirements_Specification.html",
            "title": "LCM Governance Requirements (REQ-LCM-001 - 010)",
            "description": "Authoritative functional, security, and reproducibility requirements for all repositories.",
            "category": "Requirements Spec",
            "source": "LCM_AI/docs/Requirements.md"
        },
        {
            "src": r"D:\Git_Repositories\LCM_AI\docs\Implementation.md",
            "filename": "05_LCM_Implementation_Specification.html",
            "title": "LCM Implementation Specification & Tool Manifest",
            "description": "Internal mechanics, PowerShell modules, quality gates, and automated verification harness.",
            "category": "Implementation Spec",
            "source": "LCM_AI/docs/Implementation.md"
        },
        {
            "src": r"D:\Git_Repositories\LCM_AI\docs\LCM-Rules-Cross-Reference.md",
            "filename": "06_LCM_Rules_Cross_Reference.html",
            "title": "LCM Canonical Rules Cross-Reference Matrix",
            "description": "Full matrix of all 15 governance rules, invariant descriptions, and enforcement scripts.",
            "category": "Rule Authority",
            "source": "LCM_AI/docs/LCM-Rules-Cross-Reference.md"
        }
    ]

    for d in lcm_docs:
        target = os.path.join(lcm_dir, d["filename"])
        if os.path.exists(d["src"]):
            convert_md_to_html(d["src"], target, d["title"], d["category"])
        else:
            print(f"  [WARN] Source file missing: {d['src']}")

    build_index_portal(
        lcm_dir,
        "LCM Governance Documentation Suite",
        "Authoritative architecture, requirements, implementation specifications, and rule matrices for the Lifecycle Model framework.",
        lcm_docs
    )

    print("\n=======================================================")
    print(" 2. Building HaSSD06 Subsystem Offline Documentation Suite")
    print("=======================================================")

    ha_docs = [
        {
            "src": r"D:\Git_Repositories\HaSSD06\README.md",
            "filename": "01_HaSSD06_README.html",
            "title": "HaSSD06 Subsystem Overview & Hardware Specs",
            "description": "Appliance specifications, Raspberry Pi 4 host, dual-radio layout, and diagnostic MCP tools.",
            "category": "Subsystem Overview",
            "source": "HaSSD06/README.md"
        },
        {
            "src": r"D:\Git_Repositories\HaSSD06\docs\Architecture.md",
            "filename": "02_HaSSD06_Architecture_Specification.html",
            "title": "HaSSD06 Subsystem Architecture Specification",
            "description": "Hardware topology, thermal control, multi-path dynamic endpoint probing, and Dual-HA hybrid design.",
            "category": "Subsystem Architecture",
            "source": "HaSSD06/docs/Architecture.md"
        },
        {
            "src": r"D:\Git_Repositories\HaSSD06\docs\Requirements.md",
            "filename": "03_HaSSD06_Requirements_Specification.html",
            "title": "HaSSD06 Subsystem Requirements (REQ-SUB-001 - 010)",
            "description": "JIT auth, hardware safety, Central Registry Non-Mutation Invariant, and Update-Gate lifecycle.",
            "category": "Requirements Spec",
            "source": "HaSSD06/docs/Requirements.md"
        },
        {
            "src": r"D:\Git_Repositories\HaSSD06\docs\Implementation.md",
            "filename": "04_HaSSD06_Implementation_Specification.html",
            "title": "HaSSD06 Implementation Specification & Tools Index",
            "description": "Tool mechanics, MCP read-only bridge, Update-Gate runner, and quality gate structure.",
            "category": "Implementation Spec",
            "source": "HaSSD06/docs/Implementation.md"
        },
        {
            "src": r"D:\Git_Repositories\HaSSD06\install\Installation.md",
            "filename": "05_HaSSD06_Installation_Runbook.html",
            "title": "HaSSD06 Universal Bare-Metal Installation Runbook",
            "description": "Comprehensive 7-phase runbook: SSD imaging, fan config, coordinator flashing, and HAOS onboarding.",
            "category": "Deployment Runbook",
            "source": "HaSSD06/install/Installation.md"
        },
        {
            "src": r"D:\Git_Repositories\HaSSD06\docs\HaSSD06_SYSTEM_DOCUMENTATION.md",
            "filename": "06_HaSSD06_System_Documentation.html",
            "title": "HaSSD06 System & Entity Catalog",
            "description": "Comprehensive reference of Tuya, Shelly, Zigbee, Fritz!Box devices, and entity mapping.",
            "category": "System Catalog",
            "source": "HaSSD06/docs/HaSSD06_SYSTEM_DOCUMENTATION.md"
        },
        {
            "src": r"D:\Git_Repositories\HaSSD06_Inventory\docs\SUBSYSTEM_DASHBOARD.md",
            "filename": "07_HaSSD06_Subsystem_Dashboard.html",
            "title": "HaSSD06 Subsystem Operational Dashboard & Central Registry",
            "description": "10-section operational telemetry ledger: 159 devices by brand, 74 config entries, 3 areas, and add-ons.",
            "category": "Operational Ledger",
            "source": "HaSSD06_Inventory/docs/SUBSYSTEM_DASHBOARD.md"
        }
    ]

    for d in ha_docs:
        target = os.path.join(ha_dir, d["filename"])
        if os.path.exists(d["src"]):
            convert_md_to_html(d["src"], target, d["title"], d["category"])
        else:
            print(f"  [WARN] Source file missing: {d['src']}")

    build_index_portal(
        ha_dir,
        "HaSSD06 Home Assistant OS Documentation Suite",
        "Complete appliance runbooks, architecture, requirements, system entity mappings, and operational telemetry ledgers for HaSSD06.",
        ha_docs
    )

    print("\n=======================================================")
    print(" Offline Documentation Generation COMPLETE!")
    print(f"  - LCM Package: {lcm_dir}")
    print(f"  - HaSSD06 Package: {ha_dir}")
    print("=======================================================\n")

if __name__ == "__main__":
    main()
