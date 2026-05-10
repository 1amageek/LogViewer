import SwiftUI

#Preview("Log Output") {
    Logs(lines: previewLines)
    .frame(width: 420, height: 320)
}

#Preview("Compact Rounded") {
    Logs(lines: previewLines) { line in
        PreviewLogRow(line: line)
            .padding(.horizontal, 8)
            .background(backgroundColor(for: line), in: RoundedRectangle(cornerRadius: 4))
    }
    .logTextInset(8)
    .logWrapping(.scroll)
    .frame(width: 420, height: 320)
}

#Preview("Long Lines") {
    Logs(lines: longPreviewLines) { line in
        PreviewLogRow(line: line)
            .padding(.horizontal, 12)
            .background(backgroundColor(for: line))
    }
    .logTextInset(12)
    .logWrapping(.scroll)
    .frame(width: 420, height: 260)
}

#Preview("Long Lines Wrapped") {
    Logs(lines: longPreviewLines) { line in
        PreviewWrappingLogRow(line: line)
            .padding(12)
            .background(backgroundColor(for: line))
    }
    .logWrapping(.wrap)
    .logTextInset(12)
    .frame(width: 420, height: 320)
}

#Preview("Source Filter") {
    Logs(
        source: PreviewFilteredLogSource(
            source: ArrayLogSource(previewLines),
            query: "warning"
        )
    ) { line in
        PreviewLogRow(line: line)
            .padding(.horizontal, 8)
            .background(backgroundColor(for: line), in: RoundedRectangle(cornerRadius: 4))
    }
    .logTextInset(8)
    .logWrapping(.scroll)
    .frame(width: 720, height: 320)
}

#Preview("Source Filter Empty") {
    Logs(
        source: PreviewFilteredLogSource(
            source: ArrayLogSource(previewLines),
            query: "missing"
        )
    ) { line in
        PreviewLogRow(line: line)
            .padding(.horizontal, 8)
            .background(backgroundColor(for: line), in: RoundedRectangle(cornerRadius: 4))
    }
    .logTextInset(8)
    .logWrapping(.scroll)
    .frame(width: 420, height: 320)
}

#Preview("Empty") {
    Logs(lines: [PreviewLogEntry]())
    .frame(width: 420, height: 320)
}

private let previewLines: [PreviewLogEntry] = [
    PreviewLogEntry(id: "preview:0", text: "2026-05-10T21:55:00Z [service][info] Starting local runtime"),
    PreviewLogEntry(id: "preview:1", text: "2026-05-10T21:55:01Z [service][debug] Preparing request headers"),
    PreviewLogEntry(id: "preview:2", text: "2026-05-10T21:55:02Z [service][warning] Response took longer than expected"),
    PreviewLogEntry(id: "preview:3", text: "2026-05-10T21:55:03Z [service][error] Upstream returned status 500"),
    PreviewLogEntry(id: "preview:4", text: "2026-05-10T21:55:04Z [service][info] Runtime stopped")
]

private let longPreviewLines: [PreviewLogEntry] = [
    PreviewLogEntry(
        id: "long:0",
        text: "2026-05-10T21:55:00.123Z [runtime][info] requestID=8C0F6D42-B45A-48B2-9C4A-4C45119F0E23 service=api-gateway route=/v1/workspaces/agents-in-black/repositories/1amageek/agents-in-black/branches/main method=POST status=200 durationMs=184 contentLength=48392 userAgent=AgentsInBlackPreview/1.0"
    ),
    PreviewLogEntry(
        id: "long:1",
        text: "2026-05-10T21:55:01.456Z [service][debug] command=/usr/bin/env SWIFT_DETERMINISTIC_HASHING=1 swift build --package-path /Users/1amageek/Desktop/agents-in-black --configuration debug --scratch-path /Users/1amageek/Library/Developer/Xcode/DerivedData/AgentsInBlack-gmisxtgtgdoqpbbrjxqngogdggvj/SourcePackages/checkouts"
    ),
    PreviewLogEntry(
        id: "long:2",
        text: "2026-05-10T21:55:02.789Z [service][warning] slow-log-line robotID=quadref-v0 suite=KUY-LIFT-1 task=Lift template=aerial-drone-autonomy-starter-v1 modelDescriptor=/Users/1amageek/Library/Developer/Xcode/DerivedData/Bounded-gtjduvjaezkwdrappiamyjwosglmu/Build/Products/Debug/KuyuUI.app/Contents/Resources/Models/QuadRef/quadref.model.json"
    ),
    PreviewLogEntry(
        id: "long:3",
        text: "2026-05-10T21:55:03.012Z [service][error] upstream returned invalid response traceID=3d8c5d94c0cc4b8da8a367b8c66a9e0e spanID=bcda610f1e664df4 retryCount=3 payload={\"error\":{\"code\":\"model_context_length_exceeded\",\"message\":\"The request exceeded the maximum supported context length for this runtime.\"},\"status\":500}"
    )
]

private struct PreviewLogEntry: Identifiable, CustomStringConvertible {
    let id: String
    let text: String

    var description: String {
        text
    }
}

private struct PreviewLogRow: View {
    let line: PreviewLogEntry

    var body: some View {
        Text(line.text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct PreviewWrappingLogRow: View {
    let line: PreviewLogEntry

    var body: some View {
        Text(line.text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor
private final class PreviewFilteredLogSource: LogSource {
    private let source: AnyLogSource<PreviewLogEntry>
    private let indexes: [Int]

    init<Source: LogSource>(source: Source, query: String) where Source.Line == PreviewLogEntry {
        self.source = AnyLogSource(source)

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            self.indexes = Array(0..<source.numberOfLines)
            return
        }

        var matchingIndexes: [Int] = []
        for index in 0..<source.numberOfLines {
            if source.line(at: index).text.localizedStandardContains(trimmedQuery) {
                matchingIndexes.append(index)
            }
        }
        self.indexes = matchingIndexes
    }

    var numberOfLines: Int {
        indexes.count
    }

    func line(at index: Int) -> PreviewLogEntry {
        source.line(at: indexes[index])
    }
}

private func backgroundColor(for line: PreviewLogEntry) -> Color {
    let lowercased = line.text.lowercased()
    if lowercased.contains("[error]") {
        return .red.opacity(0.20)
    }
    if lowercased.contains("[warning]") {
        return .yellow.opacity(0.18)
    }
    if lowercased.contains("[debug]") {
        return .secondary.opacity(0.12)
    }
    return .blue.opacity(0.07)
}
