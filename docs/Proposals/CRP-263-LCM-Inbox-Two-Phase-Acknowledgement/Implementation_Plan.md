# Implementation Plan: CRP-263 - LCM Inbox Two-Phase Acknowledgement

## 1. Discovery and Contract Definition

1. Trace the current inbox intake route in `Sync-GeminiInbox.ps1`, its daemon handoff, and the
   sender-visible return channel.
2. Define the durable acknowledgement schema: correlation ID, phase, timestamp, source item,
   proposal identity when applicable, terminal status, and failure reason.
3. Select the existing governed data or return-channel location that can persist acknowledgements
   without dirtying unrelated worktrees.

## 2. Phase 1 Receipt Acknowledgement

1. Generate or recover a stable correlation identity for each inbox item.
2. Persist an idempotent `received` acknowledgement immediately after discovery and before
   classification or proposal creation.
3. Ensure retry detection reads the Phase 1 record before performing duplicate work.

## 3. Phase 2 Terminal Outcome Acknowledgement

1. Emit a `success` acknowledgement only after proposal creation, payload persistence, and archive
   handling have completed.
2. Emit a terminal `failure` acknowledgement from each recoverable error boundary.
3. Include an explicit unsupported-classification failure outcome for non-intake item types.
4. Preserve the initial receipt acknowledgement and prevent multiple conflicting terminal records.

## 4. Daemon and Sender Integration

1. Expose the acknowledgement records through the existing sender-facing daemon or sync channel.
2. Return correlation identity and current phase in daemon responses where appropriate.
3. Maintain compatibility for existing inbox producers that do not yet provide an explicit
   correlation identifier.

## 5. Verification

1. Add focused Pester coverage for immediate receipt, successful terminal outcome, failed terminal
   outcome, unsupported classification, and duplicate retry.
2. Run PowerShell AST validation for changed scripts and modules.
3. Perform an inbox dry run using isolated fixture files; verify no duplicate proposal is created.
4. Run `git diff --check`.
