# Implementation Plan: CRP-283 - Machine-Registry-Only CMD Launcher Authority

## 1. Design Cycles
1. Inventory active CMD authority preambles and classify actual launcher use.
2. Define the single machine-registry preamble and its explicit failure output.
3. Migrate launchers atomically by shared pattern family.
4. Align Set-GitRoot's machine, User, and Process behavior with the authority
   contract.
5. Remove old fallback patterns only after equivalent launcher coverage exists.

## 2. Verification
- Static scan proves no active inherited, wrapper-relative, or hard-coded
  workspace-root authority remains.
- CMD syntax and target-resolution checks pass.
- Registry-unavailable tests fail explicitly without fallback.
- GoodNight, GoodMorning, and tool trampolines retain their current targets.
