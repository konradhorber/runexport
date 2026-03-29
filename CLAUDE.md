# runexport — Claude instructions

## Data model documentation

**Always update `README.md` when the data model changes.** This includes any changes to:
- `Run` fields
- `KilometerSplit` fields
- `WorkoutEvent` / `WorkoutEventType`
- The `RunExportRequest` envelope

The README is the sole reference for server-side implementors. Keep the field tables, nullability, units, and example JSON in sync with `Run.swift`.
