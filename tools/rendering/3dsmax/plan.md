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
- [x] Wire to `registerTimeCallback` (slider scrub) and
      `#preRenderEval` (per render frame) in the same
      `gspipe_plySequence.ms`. The id-based registration replaces
      prior handlers on re-fileIn; the time-callback's function
      reference is cached in `gspipe_plyTimeCallbackRef` so
      re-loads don't leak the previous registration.
- [x] Scripted custom attribute `gspipe_plySequenceSceneCA` in the
      same file. Attach it to a scene helper
      (`custAttributes.add $someHelper gspipe_plySequenceSceneCA`)
      and save the scene; on subsequent loads, its `on load` handler
      re-installs the callbacks.
- [ ] Startup script under `maxscript/startup/` that fileIns
      `gspipe_plySequence.ms`, so render-farm workers have
      `gspipe_plyCallback` defined before scenes load.
- [ ] Macroscript wrapper for menu/toolbar invocation
      (`maxscript/macros/`).
- [ ] Rollout UI for setting the user properties from inside Max
      (`maxscript/ui/`).
