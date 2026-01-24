# PeopleRun AI — Transfer Packages (Freeze-Safe)

This repository is a **freeze-safe, non-executable mirror** intended to preserve PeopleRun OS transfer packages and hard-surface snapshots.

## Authority Order (Locked)
1) **Primary Authority:** Published PeopleRun.ai hard surfaces  
2) **Secondary Authority:** This GitHub mirror (truth mirror only)  
3) **Tertiary Authority:** Append-only registry events  
4) **Non-authoritative:** Chat memory or inference

Hard surfaces override memory. Memory may never override hard surfaces.

## What this repo IS
- Preservation layer for frozen system states
- Transfer-package storage (non-executable)
- Account-loss insurance
- Verifiable historical truth via immutable Git tags (e.g., `freeze-v1`)

## What this repo is NOT
- Not an execution environment
- Not a deployment system
- Not an automation surface
- Not a place where authority is generated

## Canonical Roots (Required)
- `hard-surfaces/`
- `build-docs/`
- `registry/`
- `ops/`

## Freeze-Safety Rules (Fail-Closed)
- No direct pushes to protected branch
- No force pushes / no history rewrites
- No executable languages committed
- No secrets committed
- All changes via PR + required checks

## Tagging (Immutable)
Frozen states must be recorded via immutable annotated tags:
- `freeze-v1`, `freeze-v2`, …

## Verification
See `ops/verification/verification.md`.
