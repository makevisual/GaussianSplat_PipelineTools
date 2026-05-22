# CLAUDE.md

Orientation doc for Claude sessions working in this repo. Read this first.

## 1. Project Intent

This repo is a VFX pipeline toolset for Gaussian Splat workflows. It houses
utilities and integrations that connect tools used in the splat-to-render
pipeline: Apple Sharp, Lichtfeld, Supersplat, 3dsMax with VRay 7 Gaussian
Geometry, Foundry Nuke, and (legacy) RealityScan and PostShot.

It is **not** a renderer, not a research repo, and not user-facing software.
It is internal pipeline glue: callbacks, wrappers, format converters,
sequence handlers, and the like.

## 2. Current Pipeline Data Flow

```
  image sequence
        |
        v
  +-------------+
  | Apple Sharp |   (generation: video/images -> splat)
  +-------------+
        |
        v
   .ply sequence
        |
        v
  +-----------------------------+
  | 3dsMax + VRay 7 Gaussian    |   (rendering)
  | Geometry node               |
  +-----------------------------+
        |
        v
  rendered frames
        |
        v
  +-------+
  | Nuke  |   (compositing)
  +-------+
```

Known gap: VRay 7's Gaussian Geometry node does not natively support `.ply`
sequences (one file per frame). Closing this gap is the first planned
utility (see section 10).

## 3. Tool Inventory

| Tool          | Stage       | Host         | Status  | Folder                           |
|---------------|-------------|--------------|---------|----------------------------------|
| Apple Sharp   | generation  | standalone   | active  | `tools/generation/sharp/`        |
| RealityScan   | generation  | standalone   | legacy  | `tools/generation/realityscan/`  |
| PostShot      | generation  | standalone   | legacy  | `tools/generation/postshot/`     |
| Lichtfeld     | processing  | standalone   | active  | `tools/processing/lichtfeld/`    |
| Supersplat    | processing  | web          | active  | `tools/processing/supersplat/`   |
| ply_ops       | processing  | standalone   | active  | `tools/processing/ply_ops/`      |
| VRay Gaussian | rendering   | 3dsMax       | active  | `tools/rendering/3dsmax/`        |
| Nuke          | compositing | Nuke         | active  | `tools/compositing/nuke/`        |

## 4. Folder Structure Conventions

Top-level layout is **stage-first, host-second**:

```
tools/<stage>/<host>/
```

Example: a Houdini integration for processing splats goes in
`tools/processing/houdini/`, not `tools/houdini/processing/`.

Stages and their meanings:

- **capture** — source data ingest, camera-side prep, calibration.
- **generation** — images or video into `.ply` (or other splat formats).
- **processing** — splat editing, cleanup, transforms, format-internal ops.
- **rendering** — splat into rendered frames (DCC-host-bound).
- **compositing** — post-render image work.

Shared code consumed by more than one tool lives in
`shared/python/gspipe/`. If you find yourself copy-pasting a helper
between two tools, that's the signal to promote it to `gspipe`.

## 5. Language Conventions

3dsMax (the pattern generalises to any DCC host):

- **MaxScript (`.ms`)** — anything that touches the Max scene graph: VRay
  node properties, viewport, callbacks, modifiers, UI rollouts inside Max.
  Lives under `tools/rendering/3dsmax/maxscript/`.
- **Python** — external orchestration, file I/O outside Max, talking to
  other pipeline pieces, anything you can unit-test without launching Max.
  Lives under `tools/rendering/3dsmax/python/` or `shared/python/gspipe/`.

Rule of thumb: if it can be unit-tested without launching the host
application, write it in Python.

Same split applies to future hosts. Blender: Python addon vs external
Python. Houdini: HDAs vs external Python. Nuke: gizmos/.py vs external
Python.

## 6. Asset Versioning Convention

Test assets are versioned **per scenario**, not globally:

```
tests/assets/<scenario>/v001/
tests/assets/<scenario>/v002/
```

Rules:

- A version is **immutable** once committed. New data means a new version
  directory; never edit `v001/` after lock.
- Each version has a `manifest.yaml` documenting frame range, padding,
  source provenance, and `sha256` of each tracked file.
- Selective gitignore policy: `intermediate/` and oversize `input/` may be
  gitignored per scenario; `manifest.yaml` and `expected/` are always
  tracked.

## 7. Test Conventions

- `tests/unit/` mirrors the source tree layout. Run with `pytest` from
  the repo root.
- `tests/integration/` is **scenario-named**, not tool-named. Example:
  `tests/integration/image_to_render/`. Scenarios may launch external
  tools and may be slow.
- `tests/scenes/` holds DCC-native files (`.max`, `.blend`, `.hip`,
  `.nk`) for manual verification. Reference them from integration tests
  by version.
- Tests must not write into `tests/assets/`. Write to a temp directory.

## 8. Distribution Model

Execute in place. Clone the repo and run scripts directly. MaxScript
files are loaded via Max's startup script search path; Python scripts
are run from wherever the repo lives.

No formal installer exists. Do not introduce one without discussion —
that's a structural decision that warrants its own conversation.

## 9. Recipes

### Adding a new tool

1. Pick the stage (capture / generation / processing / rendering /
   compositing). If unclear, ask.
2. Create `tools/<stage>/<host>/<tool_name>/` (or just `tools/<stage>/<host>/`
   if the host name and tool name are the same).
3. Add a one-paragraph `README.md` describing what the tool does and how
   it's invoked.
4. If Python, add an `__init__.py` and unit test stub at the matching
   `tests/unit/...` path.
5. If MaxScript, place files under the appropriate subdir
   (`callbacks/`, `macros/`, `rollouts/`, `startup/`).

### Adding a new test scenario

1. Create `tests/integration/<scenario_name>/` with a README describing
   inputs, steps, and expected outputs.
2. Create `tests/assets/<scenario_name>/v001/` with `input/`,
   `expected/`, and a `manifest.yaml`.
3. If the scenario needs a DCC scene file, add it under
   `tests/scenes/<scenario_name>/v001/`.

### Adding a new host (e.g. Houdini)

1. For each pipeline stage the host participates in, create
   `tools/<stage>/houdini/`.
2. Mirror the MaxScript/Python split pattern: native host artefacts
   (HDAs, Python addons) in one subdir, external orchestration Python in
   another.
3. Update section 3 (Tool Inventory) of this file.

## 10. Roadmap Pointer

The first planned utility is a 3dsMax callback that loads `.ply`
sequences onto a VRayGaussianGeometry node — closing the
sequence-support gap noted in section 2. Its design will be planned in a
dedicated session before implementation. No design details are recorded
here yet, to avoid baking in unreviewed assumptions.

## 11. Don'ts

- Don't put a host at the top level of `tools/`. No `tools/3dsmax/`.
  Stage first, host second.
- Don't duplicate helpers across tools. Promote to `shared/python/gspipe/`.
- Don't mutate a committed test-asset version directory. Add a new one.
- Don't blur the MaxScript/Python responsibility line. Scene work is
  MaxScript; orchestration and testable logic is Python.
- Don't introduce a formal installer, a packaging tool, or ADRs without
  raising it first.
