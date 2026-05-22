# 3dsMax — active projects

Lightweight tracker for the work happening under
`tools/rendering/3dsmax/`. Add an entry when a project starts; mark
it done and either prune or archive when complete.

## Active

### PLY sequence loader for VRayGaussiansGeom

Closes the CLAUDE.md §2 gap: VRay 7's Gaussian Geometry node does not
natively support per-frame `.ply` sequences. A MaxScript function reads
sequence settings stored as user properties on each node and rewrites
the node's `.file` path for the current frame.

User-property contract (per node):

| Property                       | Type   | Meaning                              |
|--------------------------------|--------|--------------------------------------|
| `gspipe_plyAnimationEnabled`   | bool   | If not true, node is skipped         |
| `gspipe_plySequencePath`       | string | Path to ANY existing frame file      |
| `gspipe_plyOffset`             | int    | Added to current frame               |
| `gspipe_plySequenceMissing`    | name   | `#nearest` or `#none` (default none) |

#### Iteration status

- [x] Rename `maxscript/rollouts/` → `maxscript/ui/`.
- [x] Core function `gspipe_updatePlySequences` in
      `maxscript/callbacks/gspipe_plySequence.ms` (manual invocation only).
- [ ] Wire to time-change and scene-load callbacks with safe
      register/unregister helpers. Deferred until the core function is
      proven by manual use — misfiring callbacks force a Max restart.
- [ ] Macroscript wrapper for menu/toolbar invocation
      (`maxscript/macros/`).
- [ ] Rollout UI for setting the user properties from inside Max
      (`maxscript/ui/`).
