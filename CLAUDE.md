# runexport — Claude instructions

## Development workflow

**Use TDD.** Write the test first, then the implementation. For any new field, model change, or behaviour, the test file should be committed before or alongside the implementation — never after.

## Git strategy

**Always ask before committing.** After completing a change, ask the user if they are ready to add/commit/push — do not do it automatically. The user must test in Xcode first (run the app on device, run the test suite) since Claude cannot execute Xcode builds or tests. Only commit once the user confirms everything passes.

Each commit should be a single logical change. Do not batch unrelated changes into one commit.

## Data model documentation

**Always update `README.md` when the data model changes.** This includes any changes to:
- `Run` fields
- `KilometerSplit` fields
- `WorkoutEvent` / `WorkoutEventType`
- The `RunExportRequest` envelope

The README is the sole reference for server-side implementors. Keep the field tables, nullability, units, and example JSON in sync with `Run.swift`.
