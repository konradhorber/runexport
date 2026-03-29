# runexport — Claude instructions

## Development workflow

**Use TDD.** Write the test first, then the implementation. For any new field, model change, or behaviour, the test file should be committed before or alongside the implementation — never after.

## Data model documentation

**Always update `README.md` when the data model changes.** This includes any changes to:
- `Run` fields
- `KilometerSplit` fields
- `WorkoutEvent` / `WorkoutEventType`
- The `RunExportRequest` envelope

The README is the sole reference for server-side implementors. Keep the field tables, nullability, units, and example JSON in sync with `Run.swift`.
