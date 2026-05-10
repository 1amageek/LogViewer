# LogViewer

LogViewer is a SwiftUI log viewing package for macOS. It provides a virtualized log surface with selectable text, copy support, wrapping, and customizable row rendering.

The default view is designed for dense runtime logs and uses Xcode-like background bands for different log levels.

## Requirements

- macOS 13.0+
- Swift 6.2+

## Installation

Add the package to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/LogViewer.git", branch: "main")
]
```

Then add `LogViewer` to the target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "LogViewer", package: "LogViewer")
    ]
)
```

## Quick Start

```swift
import LogViewer
import SwiftUI

struct ContentView: View {
    private let lines = [
        LogLine(id: "0", text: "2026-05-10T21:55:00Z [runtime][info] service started"),
        LogLine(id: "1", text: "2026-05-10T21:55:01Z [runtime][warning] slow response"),
        LogLine(id: "2", text: "2026-05-10T21:55:02Z [runtime][error] upstream failed")
    ]

    var body: some View {
        Logs(lines: lines)
    }
}
```

## Source-Based Logs

Use `LogLineSource` when the log storage should own loading, filtering, or live updates.

```swift
@MainActor
final class RuntimeLogSource: LogLineSource {
    private var lines: [LogLine] = []

    var numberOfLogLines: Int {
        lines.count
    }

    func logLine(at index: Int) -> LogLine {
        lines[index]
    }

    func replace(with nextLines: [LogLine]) {
        lines = nextLines
    }
}
```

```swift
Logs(source: source)
```

## Custom Rows

`Logs` owns virtualization, scrolling, selection, and copy behavior. The row builder owns visual styling.

```swift
Logs(source: source) { line in
    Text(line.text)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.primary)
        .padding(12)
        .background(.secondary.opacity(0.12))
}
.logTextInset(12)
```

Use `logTextInsets(_:)` when the rendered text has asymmetric padding:

```swift
Logs(source: source) { line in
    Text(line.text)
        .font(.system(size: 11, design: .monospaced))
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
}
.logTextInsets(
    LogTextInsets(
        leading: 16,
        trailing: 12,
        top: 8,
        bottom: 8
    )
)
```

## Wrapping

Wrapping is enabled by default.

```swift
Logs(source: source)
    .logLineWrapping(.wrap)
```

Use horizontal scrolling for single-line log views:

```swift
Logs(source: source) { line in
    Text(line.text)
        .font(.system(size: 11, design: .monospaced))
        .lineLimit(1)
}
.logLineWrapping(.scroll)
```

## Filtering

Filtering belongs in the source, not the view. This keeps the viewer focused on rendering and preserves predictable behavior for large datasets.

```swift
@MainActor
final class FilteredLogLineSource: LogLineSource {
    private let source: any LogLineSource
    private let indexes: [Int]

    init(source: any LogLineSource, query: String) {
        self.source = source

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            self.indexes = Array(0..<source.numberOfLogLines)
            return
        }

        var matchingIndexes: [Int] = []
        for index in 0..<source.numberOfLogLines {
            if source.logLine(at: index).text.localizedStandardContains(trimmedQuery) {
                matchingIndexes.append(index)
            }
        }
        self.indexes = matchingIndexes
    }

    var numberOfLogLines: Int {
        indexes.count
    }

    func logLine(at index: Int) -> LogLine {
        source.logLine(at: indexes[index])
    }
}
```

## Performance Model

LogViewer does not create SwiftUI rows for the entire log collection. It hosts only the rows intersecting the visible viewport and reads lines through `LogLineSource` by index.

```text
LogLineSource
    -> Logs
        -> virtual AppKit document view
            -> visible SwiftUI row hosts
```

For wrapped logs, row heights are calculated from monospaced text metrics and cached for the current content width.

## Selection and Copy

Rows are rendered by SwiftUI, while text selection is handled by the virtual host view. This allows pointer selection, Command-C, and Command-A without forcing every log line into a native text view.
