# TodoList

A native macOS SwiftUI todo list starter app.

## Features

- Sidebar filters for All, Today, Upcoming, and Completed
- Searchable todo list with native macOS selection
- Editable detail pane for title, completion, due date, and notes
- JSON persistence in `~/Library/Application Support/TodoList/todos.json`
- Generated macOS app icon embedded in `dist/TodoList.app`
- Sidebar settings button with an app-wide font picker
- Menu commands and shortcuts:
  - `Command-N`: new todo
  - `Command-L`: toggle completion
  - `Delete`: delete selected todo
- Project-local app bundle staging through `script/build_and_run.sh`
- Codex Run action in `.codex/environments/environment.toml`

## Build And Run

From this directory:

```bash
./script/build_and_run.sh
```

The script builds the SwiftPM product, stages `dist/TodoList.app`, embeds the
app icon, and opens it as a foreground macOS app bundle.

If Xcode has not been launched before, accept the Xcode license in Terminal:

```bash
sudo xcodebuild -license
```

Then run the build script again.

## Test

```bash
swift test
```
