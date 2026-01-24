# Verification — Freeze-Safe Mirror

A valid mirror MUST satisfy:

- Branch protections enabled (main)
- PR review required
- Status checks required (Freeze Guard)
- No force pushes
- No history rewrites
- Guard workflow active
- No executable files present
- No secrets present
- Canonical roots present
- Immutable freeze tags used for frozen states

Failure of any condition invalidates this mirror as trusted.
