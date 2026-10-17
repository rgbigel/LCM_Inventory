# Walkthrough: CRP-283 - Machine-Registry-Only CMD Launcher Authority

## 1. Design Status
Suggested successor to CRP-250. No CMD or Set-GitRoot mutation has started.

## 2. Inherited Evidence
CRP-250 established the shared registry resolver and migrated core lifecycle
tools. Current analysis found active fallback authority patterns in 229 CMD
wrappers; this proposal owns only that remaining authority migration.
