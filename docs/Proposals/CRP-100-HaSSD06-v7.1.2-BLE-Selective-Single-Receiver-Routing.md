---
Proposal-ID: CRP-100
CR-ID: CR-2026-049
Scope: HaSSD06
Version: v7.1.2
Affected-Repos: [HaSSD06, HaSSD06_Inventory]
Status: Suggested
Date: 2026-08-31
Author: Rolf, Workspace_AI Engine
Target Scope: HaSSD06 / Bluetooth Architecture & Multi-Hub Ingestion
Affected Version Range: v7.1.1 -> v7.1.2
Impacted Repositories: [HaSSD06, HaSSD06_Inventory]
---

# CRP-100: Prevent BLE Packet Collisions by Enforcing Selective Single-Receiver Ingestion

## 1. Executive Summary & Intent
Prevent RF packet collisions, multi-proxy race conditions, and rapid state flapping across Bluetooth Low Energy (BLE) devices in Home Assistant by enforcing selective, deterministic single-receiver routing. 

Rather than allowing multiple unsynchronized Bluetooth scanners (e.g. Raspberry Pi onboard Broadcom adapter and Shelly BLU Gateway G3) to concurrently ingest and forward overlapping advertisement bursts for the same physical sensors, this policy establishes explicit single-receiver assignments per sensor family or physical zone.

## 2. Problem Statement & Operational Findings
1. **Multi-Receiver Contention**: When multiple Bluetooth proxies receive the same broadcast packet with differing latencies (e.g. direct HCI UART vs Wi-Fi RPC proxy), Home Assistant's state engine receives duplicate state updates within milliseconds, generating artificial state churn and micro-dropouts.
2. **Protocol Specificity**:
   * **BTHome / Shelly Probes & TRVs**: 100% stable when routed exclusively through the `shellyblugwg3` Shelly BLU Gateway G3 proxy.
   * **Govee H5075 (Proprietary Manufacturer Data `0xEC88`)**: Reliably captured only by the Raspberry Pi onboard Bluetooth adapter (`hci0`).
3. **Objective**: Configure Home Assistant Bluetooth integration filters, scanner configurations, or integration options so that each device binds to its designated single receiver, preventing collision jitter without losing coverage.

## 3. Proposed Implementation Phases
1. **Receiver Mapping Architecture**: Formalize the receiver assignment table:
   * Govee H5075 $	o$ Locked to Raspberry Pi `hci0` (`D8:3A:DD:16:D4:F7`).
   * Shelly TRVs & BTHome Sensors $	o$ Locked to `shellyblugwg3` (`B0:81:84:E5:56:50`).
2. **Scanner Filter Configuration**: Evaluate Home Assistant `bluetooth` scanner source binding / proxy filtering to prevent duplicate cross-ingestion.
3. **Telemetry & Validation**: Verify zero collision flapping (<10s cycles) while maintaining continuous 24/7 data flow across all 33 entities.


