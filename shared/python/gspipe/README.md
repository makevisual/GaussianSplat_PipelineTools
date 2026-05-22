# gspipe

Shared, host-agnostic Python helpers consumed by multiple tools. Import
as `gspipe.<module>` once the package is on the Python path.

A helper belongs here when more than one tool needs it (sequence
parsing, `.ply` I/O, logging, path resolution). If a helper has only one
caller, keep it next to that caller until a second consumer appears.

No `pyproject.toml` exists yet; the package is currently used by adding
`shared/python/` to `PYTHONPATH` or by direct execution. A formal
install model can be added later.
