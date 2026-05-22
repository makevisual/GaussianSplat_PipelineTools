# tools

All pipeline tools. Organised **stage-first, host-second**:

```
tools/<stage>/<host>/
```

Stages:

- `capture/` — source data ingest, calibration, camera-side prep.
- `generation/` — images or video into `.ply` (or other splat formats).
- `processing/` — splat editing, cleanup, transforms.
- `rendering/` — splat into rendered frames (DCC-host-bound).
- `compositing/` — post-render image work.

A new tool goes under the stage it participates in, then the host it
runs in (or `standalone/` for host-agnostic CLIs). See `CLAUDE.md`
section 9 for the full recipe.
