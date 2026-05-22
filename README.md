# GaussianSplat_PipelineTools

Internal VFX pipeline toolset for Gaussian Splat workflows. Houses
utilities and integrations across the splat-to-render pipeline: Apple
Sharp, Lichtfeld, Supersplat, 3dsMax with VRay 7 Gaussian Geometry,
Foundry Nuke, and legacy tools (RealityScan, PostShot).

Tools are organised **stage-first, host-second**:

```
tools/<stage>/<host>/
```

See [CLAUDE.md](CLAUDE.md) for conventions, structure, and recipes.

## Layout

- `tools/` — pipeline tools, grouped by stage (capture, generation,
  processing, rendering, compositing) then host (3dsmax, nuke, etc.).
- `shared/python/gspipe/` — shared, host-agnostic Python helpers
  consumed by multiple tools.
- `tests/` — unit tests, integration scenarios, versioned test assets,
  and manual DCC test scenes.
- `docs/` — long-form documentation.
