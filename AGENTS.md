# Project instructions

## Overview

TodoList is a native macOS todo application built with SwiftUI and AppKit.
It uses Swift Package Manager, with Swift tools version 5.9 and a declared
minimum deployment target of macOS 14. The README reports testing only on
macOS 27; do not treat the deployment target as verified compatibility.
There are currently no third-party package dependencies.

## Project layout

- `Package.swift`: executable, library, and test target definitions.
- `Sources/TodoList/App/`: application entry point and AppKit delegate.
- `Sources/TodoList/Views/`: sidebar, task list, task details, and settings.
- `Sources/TodoList/Support/`: commands, selection, typography, and icons.
- `Sources/TodoCore/Models/`: tasks, tags, filters, and recurrence rules.
- `Sources/TodoCore/Stores/`: observable store and JSON persistence.
- `Tests/TodoCoreTests/TodoStoreTests.swift`: core behavior and persistence
  tests using XCTest.
- `Assets/`: application icon sources and bundled icon.
- `todos.json`: sample data used to seed the application.
- `script/build_and_run.sh`: build, bundle, sign, and launch helper.
- `.build/` and `dist/`: generated build artifacts; do not edit manually.

## Build and validation

Run commands from the project root on macOS with Xcode installed:

```bash
swift build --product TodoList
swift test
swift test --filter TodoStoreTests.testAddUpdateToggleAndReload
```

If Swift commands cannot locate the full Xcode toolchain, set
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for the command
when Xcode is installed at that path. Do not change global toolchain settings.

To build an application bundle and launch it:

```bash
bash ./script/build_and_run.sh
```

The script terminates a running TodoList process, rebuilds
`dist/TodoList.app`, attempts ad hoc signing, and launches the app. Its
`--debug`, `--logs`, `--telemetry`, and `--verify` modes also rebuild the
bundle; `--verify` launches it and checks that the process exists. Use
`swift build` for compilation checks that do not launch the application.

For core behavior changes, run the relevant XCTest cases and the full
suite when practical. For UI changes, also build the executable and check
the affected interaction when launching the app is within scope. Report
which checks ran and any checks that could not run. Documentation-only
changes do not require building or launching the application.

## Architecture and coding conventions

- Keep task behavior, recurrence, filtering, ordering, and persistence in
  `TodoCore`; keep SwiftUI and AppKit presentation in `TodoList`.
- Follow the surrounding Swift style: four-space indentation, UpperCamelCase
  type names, lowerCamelCase members, and one argument per line for long
  calls and declarations. Align closing delimiters with the construct.
- Preserve `TodoStore` main-actor isolation and use its mutation methods
  from views. Store changes trigger persistence through published properties.
- Reuse the existing typography, tag, selection, and command helpers.
- Prefer Apple frameworks and existing helpers over new dependencies.
- Keep edits focused on the requested task; avoid unrelated formatting,
  renames, or changes to README.md and other unrelated files.

## Persistence and tests

Real user data lives at
`~/Library/Application Support/TodoList/todos.json`. Never overwrite,
delete, or use this file as a test fixture. Launching the app can update
this data through startup lifecycle handling and autosave.

Persistence uses ISO 8601 dates and atomic JSON writes. Preserve support
for legacy task arrays and snapshots missing newer fields. The current
snapshot stores active tasks, recurrent events, tags, and trash items.

Tests should inject `TodoPersistence(fileURL:)` with a temporary location
and use `TodoStore(persistence: ..., seedSamples: false)` to avoid real
user data and sample seeding. Follow the existing `@MainActor` XCTest
pattern and use explicit dates and calendars for date-sensitive behavior.
Cover meaningful behavior changes, particularly recurrence, ordering,
subtasks, trash recovery, and persistence compatibility.

## Environment boundaries

- Perform project work locally. Do not connect to saved remote servers
  through SSH, SCP, rsync, or other tools. If server work is requested,
  provide commands for the user to run themselves.
- Use `$TMPDIR` for shell temporary files rather than hard-coding `/tmp`.
- Do not change the base Conda environment or create new environments.
- If Python tooling is needed, follow the user's Python style: PEP 8 with
  a 72-character line limit, double-quoted strings, four-space indentation,
  and standalone opening and closing triple quotes for function docstrings.
  Keep path strings on one line and use script-relative paths for analysis
  scripts. Avoid new dependencies when existing tools suffice.
- For any necessary Python package installation, use `uv pip install`
  with a dry run first; ask before upgrading or downgrading other packages.
