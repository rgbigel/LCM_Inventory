-- ==========================================================================
-- LCM Strategies Ledger Canonical SQL Dump (Git-Reviewable Text Projection)
-- Schema Version: 1.0 (Deterministic SQL Projection)
-- Total Strategies: 4
-- ==========================================================================

BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS strategies (
    strategy_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    state TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS strategy_crps (
    strategy_id TEXT NOT NULL,
    crp_id TEXT NOT NULL,
    goal_role TEXT NOT NULL,
    PRIMARY KEY (strategy_id, crp_id)
);

DELETE FROM strategy_crps;
DELETE FROM strategies;

INSERT INTO strategies (strategy_id, title, description, state, created_at, updated_at) VALUES ('STRAT-001', 'Tool Taxonomy, Fast Discovery & High-Performance Execution', 'Unify tool taxonomy across SubSystems, absorb redundant roles into enriched functional categories, provide high-speed index discovery, and establish native Go execution via LCM DO (do.exe).', 'active', '2026-11-12 12:00:00', '2026-11-12 19:20:00');
INSERT INTO strategies (strategy_id, title, description, state, created_at, updated_at) VALUES ('STRAT-002', 'SQLite Dual-State Ledgers & Version Isolation', 'Modernize workspace catalogs and ledgers to high-performance SQLite engines (proposals.db, tools.db) with canonical Git SQL projections, automated hooks, and sandbox metadata binding.', 'active', '2026-11-12 12:00:00', '2026-11-12 19:20:00');
INSERT INTO strategies (strategy_id, title, description, state, created_at, updated_at) VALUES ('STRAT-003', 'System-1 Decision Cascade & Requalification Governance', 'Establish multi-stage System-1 decision cascade governance, Gate 2A documentation stabilization checkpoint, and automated stepwise requalification with dynamic remediation injection.', 'active', '2026-11-12 12:00:00', '2026-11-12 19:20:00');
INSERT INTO strategies (strategy_id, title, description, state, created_at, updated_at) VALUES ('STRAT-004', 'Storage, Junctions & Workspace Mounting Architecture', 'Architect flexible workspace boundaries, child repository junction management, hybrid Git World mounting, and read-only Macrium snapshot baseline review workflows.', 'active', '2026-11-12 12:00:00', '2026-11-12 19:20:00');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-001', 'CRP-204', 'aligns');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-001', 'CRP-213', 'aligns');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-001', 'CRP-320', 'delivers');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-001', 'CRP-323', 'delivers');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-002', 'CRP-322', 'delivers');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-002', 'CRP-324', 'delivers');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-003', 'CRP-252', 'delivers');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-003', 'CRP-321', 'delivers');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-004', 'CRP-253', 'delivers');
INSERT INTO strategy_crps (strategy_id, crp_id, goal_role) VALUES ('STRAT-004', 'CRP-268', 'aligns');

COMMIT;
