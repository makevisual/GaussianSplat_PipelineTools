# 3dsmax

3dsMax + VRay 7 Gaussian Geometry integration.

Language split (see `CLAUDE.md` section 5):

- `maxscript/` — anything that touches the Max scene: callbacks, macros,
  rollouts, startup scripts, VRay node property access. Subdirs:
  - `callbacks/` — time-change, scene-load, render pre/post callbacks.
  - `macros/` — macroscripts wired into toolbars and menus.
  - `rollouts/` — user-facing dialog UIs.
  - `startup/` — auto-loaded scripts (drop into Max's startup folder).
- `python/` — external orchestration: launching Max, sending jobs to
  Max, talking between Max and the rest of the pipeline. No scene
  manipulation here; that belongs in `maxscript/`.
