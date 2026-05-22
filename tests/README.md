# tests

Four siblings, each with a distinct purpose:

- `unit/` — Pure-Python unit tests. Mirrors the source tree layout. Run
  with `pytest` from the repo root. Fast; no host launches.
- `integration/` — Scenario-named end-to-end tests. May launch external
  tools (Apple Sharp, 3dsMax, Nuke). Slower; may require DCC hosts.
- `scenes/` — DCC-native files (`.max`, `.blend`, `.hip`, `.nk`) for
  manual verification or driven by integration tests. Organised by
  scenario and version.
- `assets/` — Versioned test data (footage, splats, expected outputs).
  Per-scenario versioning (`vNNN/`). See `assets/README.md` for the
  full convention.

Tests must not write into `tests/assets/`. Write to a temp directory.
