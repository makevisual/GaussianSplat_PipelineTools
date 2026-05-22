# assets

Versioned test data: footage, `.ply` sequences, golden outputs.

## Layout

```
assets/<scenario>/v001/
assets/<scenario>/v002/
```

Versioning is **per scenario**, not global. Each version directory is
**immutable** once committed — new data means a new version.

## Contents of a version directory

```
assets/<scenario>/v001/
  input/          source images, video, or other raw input
  intermediate/   derived artefacts (e.g. .ply sequences from Sharp)
  expected/       golden outputs for comparison
  manifest.yaml   frame range, padding, source provenance, sha256s
```

`manifest.yaml` and `expected/` are always tracked. `intermediate/` and
oversize `input/` may be selectively gitignored if a dataset grows too
large — add the pattern in the root `.gitignore`.

## ply_samples

`ply_samples/` holds tiny generic `.ply` files for unit tests
(synthetic, a handful of points each). Always in-repo. Not
scenario-versioned.
