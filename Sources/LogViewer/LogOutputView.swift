import AppKit
import SwiftUI

@MainActor
public protocol LogSource<Line>: AnyObject {
    associatedtype Line: Identifiable

    var numberOfLines: Int { get }
    func line(at index: Int) -> Line
}

public final class AnyLogSource<Line: Identifiable>: LogSource {
    private let countProvider: () -> Int
    private let lineProvider: (Int) -> Line

    public init<Source: LogSource>(_ source: Source) where Source.Line == Line {
        self.countProvider = { source.numberOfLines }
        self.lineProvider = { source.line(at: $0) }
    }

    public var numberOfLines: Int {
        countProvider()
    }

    public func line(at index: Int) -> Line {
        lineProvider(index)
    }
}

public final class CollectionLogSource<Data: RandomAccessCollection>: LogSource where Data.Element: Identifiable {
    public typealias Line = Data.Element

    private let data: Data

    public init(_ data: Data) {
        self.data = data
    }

    public var numberOfLines: Int {
        data.count
    }

    public func line(at index: Int) -> Line {
        data[data.index(data.startIndex, offsetBy: index)]
    }
}

public final class ArrayLogSource<Line: Identifiable>: LogSource {
    private let lines: [Line]

    public init(_ lines: [Line]) {
        self.lines = lines
    }

    public var numberOfLines: Int {
        lines.count
    }

    public func line(at index: Int) -> Line {
        lines[index]
    }
}

public final class EmptyLogSource<Line: Identifiable>: LogSource {
    public init() {}

    public convenience init(_ lineType: Line.Type) {
        self.init()
    }

    public var numberOfLines: Int {
        0
    }

    public func line(at index: Int) -> Line {
        preconditionFailure("Empty log source has no line at index \(index).")
    }
}

public final class CompositeLogSource<Line: Identifiable>: LogSource {
    private let sources: [AnyLogSource<Line>]

    public init(_ sources: [AnyLogSource<Line>]) {
        self.sources = sources
    }

    public convenience init<Sources: Sequence>(_ sources: Sources) where Sources.Element: LogSource, Sources.Element.Line == Line {
        self.init(sources.map { AnyLogSource($0) })
    }

    public var numberOfLines: Int {
        sources.reduce(0) { $0 + $1.numberOfLines }
    }

    public func line(at index: Int) -> Line {
        var remainingIndex = index
        for source in sources {
            let count = source.numberOfLines
            if remainingIndex < count {
                return source.line(at: remainingIndex)
            }
            remainingIndex -= count
        }
        preconditionFailure("Log line index \(index) is outside the source bounds.")
    }
}

public enum LogWrapping: Sendable {
    case scroll
    case wrap
}

public struct LogTextInsets: Sendable {
    public var leading: CGFloat
    public var trailing: CGFloat
    public var top: CGFloat
    public var bottom: CGFloat

    public init(
        leading: CGFloat = 0,
        trailing: CGFloat = 0,
        top: CGFloat = 0,
        bottom: CGFloat = 0
    ) {
        self.leading = leading
        self.trailing = trailing
        self.top = top
        self.bottom = bottom
    }
}

public struct Logs<Line: Identifiable, RowContent: View>: View {
    private var hostConfiguration = HostConfiguration()
    private let source: AnyLogSource<Line>
    private let text: (Line) -> String
    private let rowContent: (Line) -> RowContent

    public init<Source: LogSource>(
        source: Source,
        text: KeyPath<Line, String>,
        @ViewBuilder rowContent: @escaping (Line) -> RowContent
    ) where Source.Line == Line {
        self.source = AnyLogSource(source)
        self.text = { $0[keyPath: text] }
        self.rowContent = rowContent
    }

    public init<Data: RandomAccessCollection>(
        _ data: Data,
        text: KeyPath<Line, String>,
        @ViewBuilder rowContent: @escaping (Line) -> RowContent
    ) where Data.Element == Line {
        self.init(
            source: CollectionLogSource(data),
            text: text,
            rowContent: rowContent
        )
    }

    public init(
        lines: [Line],
        text: KeyPath<Line, String>,
        @ViewBuilder rowContent: @escaping (Line) -> RowContent
    ) {
        self.init(
            source: ArrayLogSource(lines),
            text: text,
            rowContent: rowContent
        )
    }

    public var body: some View {
        VirtualLogHostingScrollView(
            source: source,
            text: text,
            hostConfiguration: hostConfiguration,
            rowContent: rowContent
        )
    }

    public func logWrapping(_ wrapping: LogWrapping) -> Self {
        var copy = self
        copy.hostConfiguration.wrapping = wrapping
        return copy
    }

    public func logTextInset(_ inset: CGFloat) -> Self {
        logTextInsets(
            LogTextInsets(
                leading: inset,
                trailing: inset,
                top: inset,
                bottom: inset
            )
        )
    }

    public func logTextInsets(_ insets: LogTextInsets) -> Self {
        var copy = self
        copy.hostConfiguration.textInsets = insets
        return copy
    }
}

public extension Logs where RowContent == LogRow {
    init<Source: LogSource>(
        source: Source,
        text: KeyPath<Line, String>
    ) where Source.Line == Line {
        self.init(source: source, text: text) { line in
            LogRow(text: line[keyPath: text])
        }
        hostConfiguration.textInsets = LogRow.textInsets
        hostConfiguration.wrapping = .wrap
        hostConfiguration.backgroundColor = .xcodeLogBackground
    }

    init<Data: RandomAccessCollection>(
        _ data: Data,
        text: KeyPath<Line, String>
    ) where Data.Element == Line {
        self.init(source: CollectionLogSource(data), text: text)
    }

    init(lines: [Line], text: KeyPath<Line, String>) {
        self.init(source: ArrayLogSource(lines), text: text)
    }
}

private struct HostConfiguration {
    let rowHeight: CGFloat = 24
    let wrappedLineHeight: CGFloat = 17
    let minimumContentWidth: CGFloat = 1_200
    let bottomStickThreshold: CGFloat = 40
    let selectionFont: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    var backgroundColor = NSColor.textBackgroundColor
    var textInsets = LogTextInsets()
    var wrapping: LogWrapping = .wrap

    var selectionCharacterWidth: CGFloat {
        ("M" as NSString).size(withAttributes: [.font: selectionFont]).width
    }
}

private extension NSColor {
    static let xcodeLogBackground = NSColor(
        calibratedRed: 0.14,
        green: 0.15,
        blue: 0.18,
        alpha: 1
    )
}

private struct VirtualLogHostingScrollView<Line: Identifiable, RowContent: View>: NSViewRepresentable {
    let source: AnyLogSource<Line>
    let text: (Line) -> String
    let hostConfiguration: HostConfiguration
    let rowContent: (Line) -> RowContent

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = hostConfiguration.wrapping == .scroll
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = hostConfiguration.backgroundColor
        scrollView.borderType = .noBorder
        scrollView.contentView.postsBoundsChangedNotifications = true

        let documentView = VirtualLogHostingDocumentView<Line, RowContent>()
        documentView.configure(
            source: source,
            text: text,
            hostConfiguration: hostConfiguration,
            viewportSize: scrollView.contentSize,
            rowContent: rowContent
        )

        scrollView.documentView = documentView
        context.coordinator.documentView = documentView
        context.coordinator.scrollView = scrollView
        context.coordinator.observeBoundsChanges(in: scrollView.contentView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let documentView = context.coordinator.documentView else { return }
        let wasAtBottom = context.coordinator.isAtBottom()
        scrollView.hasHorizontalScroller = hostConfiguration.wrapping == .scroll
        scrollView.backgroundColor = hostConfiguration.backgroundColor
        documentView.configure(
            source: source,
            text: text,
            hostConfiguration: hostConfiguration,
            viewportSize: scrollView.contentSize,
            rowContent: rowContent
        )
        if wasAtBottom {
            context.coordinator.scrollToBottom()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.stopObservingBoundsChanges()
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var documentView: VirtualLogHostingDocumentView<Line, RowContent>?
        weak var scrollView: NSScrollView?

        private let hostConfiguration = HostConfiguration()

        func stopObservingBoundsChanges() {
            NotificationCenter.default.removeObserver(self)
        }

        func observeBoundsChanges(in clipView: NSClipView) {
            stopObservingBoundsChanges()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(clipViewBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView,
            )
        }

        @objc private func clipViewBoundsDidChange(_ notification: Notification) {
            documentView?.updateVisibleRows()
        }

        func isAtBottom() -> Bool {
            guard let scrollView, let documentView else { return true }
            let visible = scrollView.contentView.bounds
            return visible.maxY >= documentView.frame.height - hostConfiguration.bottomStickThreshold
        }

        func scrollToBottom() {
            guard let scrollView, let documentView else { return }
            let visibleHeight = scrollView.contentView.bounds.height
            let y = max(0, documentView.frame.height - visibleHeight)
            scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.minX, y: y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            documentView.updateVisibleRows()
        }
    }
}

private struct SelectionPosition: Comparable, Equatable {
    let row: Int
    let column: Int

    static func < (lhs: SelectionPosition, rhs: SelectionPosition) -> Bool {
        if lhs.row != rhs.row {
            return lhs.row < rhs.row
        }
        return lhs.column < rhs.column
    }
}

private struct TextSelection {
    let anchor: SelectionPosition
    let focus: SelectionPosition

    var normalized: (lower: SelectionPosition, upper: SelectionPosition) {
        anchor <= focus ? (anchor, focus) : (focus, anchor)
    }
}

private final class VirtualLogHostingDocumentView<Line: Identifiable, RowContent: View>: NSView {
    private var source: AnyLogSource<Line>?
    private var text: ((Line) -> String)?
    private var hostConfiguration = HostConfiguration()
    private var rowContent: ((Line) -> RowContent)?
    private var hostedRows: [Int: LogRowHostingView<RowContent>] = [:]
    private var selectionOverlays: [Int: SelectionOverlayView] = [:]
    private var textSelection: TextSelection?
    private var rowHeights: [CGFloat] = []
    private var rowOffsets: [CGFloat] = []
    private var cachedRowMetricsWidth: CGFloat = 0
    private var cachedRowMetricsCount: Int = -1
    private var cachedWrapping: LogWrapping = .scroll
    private var cachedSourceIdentifier: ObjectIdentifier?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = hostConfiguration.backgroundColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var displayCount: Int {
        source?.numberOfLines ?? 0
    }

    func configure(
        source: AnyLogSource<Line>,
        text: @escaping (Line) -> String,
        hostConfiguration: HostConfiguration,
        viewportSize: NSSize,
        rowContent: @escaping (Line) -> RowContent
    ) {
        self.source = source
        self.text = text
        self.hostConfiguration = hostConfiguration
        self.rowContent = rowContent
        layer?.backgroundColor = hostConfiguration.backgroundColor.cgColor

        pruneSelection()
        rebuildRowMetricsIfNeeded(viewportSize: viewportSize)
        updateFrameSize(viewportSize: viewportSize)
        updateVisibleRows()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        let viewportSize = superview?.bounds.size ?? .zero
        rebuildRowMetricsIfNeeded(viewportSize: viewportSize)
        updateFrameSize(viewportSize: viewportSize)
        updateVisibleRows()
    }

    override func layout() {
        super.layout()
        let viewportSize = superview?.bounds.size ?? .zero
        rebuildRowMetricsIfNeeded(viewportSize: viewportSize)
        updateFrameSize(viewportSize: viewportSize)
        updateVisibleRows()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .iBeam)
    }

    override func mouseDown(with event: NSEvent) {
        guard let position = selectionPosition(for: event) else { return }
        window?.makeFirstResponder(self)

        if event.modifierFlags.contains(.shift), let anchor = textSelection?.anchor {
            textSelection = TextSelection(anchor: anchor, focus: position)
        } else {
            textSelection = TextSelection(anchor: position, focus: position)
        }
        updateVisibleRows()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let position = selectionPosition(for: event) else { return }
        let anchor = textSelection?.anchor ?? position
        textSelection = TextSelection(anchor: anchor, focus: position)
        autoscroll(with: event)
        updateVisibleRows()
    }

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased()
        if event.modifierFlags.contains(.command), key == "c" {
            copySelectionToPasteboard()
            return
        }
        if event.modifierFlags.contains(.command), key == "a" {
            selectAll(nil)
            return
        }
        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) {
        copySelectionToPasteboard()
    }

    private func copySelectionToPasteboard() {
        guard let textSelection, let source else { return }
        let text = selectedText(for: textSelection, source: source)
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    override func selectAll(_ sender: Any?) {
        guard displayCount > 0 else { return }
        let lastRow = displayCount - 1
        let lastColumn: Int
        if let source, let text {
            lastColumn = text(source.line(at: lastRow)).count
        } else {
            lastColumn = 0
        }
        textSelection = TextSelection(
            anchor: SelectionPosition(row: 0, column: 0),
            focus: SelectionPosition(row: lastRow, column: lastColumn)
        )
        updateVisibleRows()
    }

    func updateVisibleRows() {
        guard let source, let rowContent else { return }

        if source.numberOfLines == 0 || displayCount == 0 {
            removeAllRows()
            clearSelection()
            return
        }

        let visibleRect = enclosingScrollView?.contentView.bounds ?? bounds
        let range = visibleRowRange(dirtyRect: visibleRect)

        let visibleIndexes = Set(range)
        for index in hostedRows.keys where !visibleIndexes.contains(index) {
            hostedRows.removeValue(forKey: index)?.removeFromSuperview()
        }

        for displayIndex in range {
            let line = source.line(at: displayIndex)
            let hostingView: LogRowHostingView<RowContent>
            if let existing = hostedRows[displayIndex] {
                existing.rootView = rowContent(line)
                hostingView = existing
            } else {
                let created = LogRowHostingView(rootView: rowContent(line))
                created.sizingOptions = []
                addSubview(created)
                hostedRows[displayIndex] = created
                hostingView = created
            }
            hostingView.frame = rowFrame(for: displayIndex)
        }

        updateSelectionOverlays(visibleRange: range)
    }

    private func rowFrame(for displayIndex: Int) -> NSRect {
        NSRect(
            x: 0,
            y: rowOffset(for: displayIndex),
            width: bounds.width,
            height: rowHeight(for: displayIndex)
        )
    }

    private func removeAllRows() {
        hostedRows.values.forEach { $0.removeFromSuperview() }
        hostedRows.removeAll(keepingCapacity: true)
        selectionOverlays.values.forEach { $0.removeFromSuperview() }
        selectionOverlays.removeAll(keepingCapacity: true)
    }

    private func selectionPosition(for event: NSEvent) -> SelectionPosition? {
        guard displayCount > 0, hostConfiguration.rowHeight > 0 else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let row = rowIndex(atY: point.y)
        let localY = max(0, point.y - rowOffset(for: row))
        return SelectionPosition(
            row: row,
            column: columnIndex(forX: point.x, localY: localY, row: row)
        )
    }

    private func columnIndex(forX x: CGFloat, localY: CGFloat, row: Int) -> Int {
        guard let source, let text else { return 0 }
        let line = source.line(at: row)
        let lineText = text(line)
        let characterWidth = max(hostConfiguration.selectionCharacterWidth, 1)
        let relativeX = max(0, x - hostConfiguration.textInsets.leading)
        let visualColumn = Int((relativeX / characterWidth).rounded(.down))
        let visualLine: Int
        let columnsPerVisualLine: Int
        switch hostConfiguration.wrapping {
        case .scroll:
            visualLine = 0
            columnsPerVisualLine = Int.max
        case .wrap:
            let textY = max(0, localY - hostConfiguration.textInsets.top)
            visualLine = max(0, Int(floor(textY / max(hostConfiguration.wrappedLineHeight, 1))))
            columnsPerVisualLine = wrappedColumnsPerVisualLine(contentWidth: bounds.width)
        }
        let column = visualLine * columnsPerVisualLine + visualColumn
        return min(max(column, 0), lineText.count)
    }

    private func clearSelection() {
        textSelection = nil
        selectionOverlays.values.forEach { $0.removeFromSuperview() }
        selectionOverlays.removeAll(keepingCapacity: true)
    }

    private func pruneSelection() {
        let count = displayCount
        if count == 0 {
            clearSelection()
            return
        }
        if let textSelection {
            self.textSelection = TextSelection(
                anchor: clampedPosition(textSelection.anchor, rowCount: count),
                focus: clampedPosition(textSelection.focus, rowCount: count)
            )
        }
    }

    private func updateSelectionOverlays(visibleRange: Range<Int>) {
        let visibleSelectedRows = selectedRowRange(visibleRange: visibleRange)

        for index in selectionOverlays.keys where visibleSelectedRows?.contains(index) != true {
            selectionOverlays.removeValue(forKey: index)?.removeFromSuperview()
        }

        guard let visibleSelectedRows else { return }
        for index in visibleSelectedRows {
            let overlay: SelectionOverlayView
            if let existing = selectionOverlays[index] {
                overlay = existing
            } else {
                let created = SelectionOverlayView()
                selectionOverlays[index] = created
                overlay = created
            }
            let rowFrame = rowFrame(for: index)
            overlay.frame = rowFrame
            overlay.selectionRects = selectionRects(for: index, rowFrame: rowFrame)
            if overlay.superview == nil {
                addSubview(overlay, positioned: .above, relativeTo: nil)
            } else {
                overlay.removeFromSuperview()
                addSubview(overlay, positioned: .above, relativeTo: nil)
            }
        }
    }

    private func clampedPosition(_ position: SelectionPosition, rowCount: Int) -> SelectionPosition {
        guard rowCount > 0, let source, let text else { return SelectionPosition(row: 0, column: 0) }
        let row = min(max(position.row, 0), rowCount - 1)
        let column = min(max(position.column, 0), text(source.line(at: row)).count)
        return SelectionPosition(row: row, column: column)
    }

    private func selectedRowRange(visibleRange: Range<Int>) -> ClosedRange<Int>? {
        guard let textSelection else { return nil }
        let normalized = textSelection.normalized
        let lower = max(normalized.lower.row, visibleRange.lowerBound)
        let upper = min(normalized.upper.row, visibleRange.upperBound - 1)
        return lower <= upper ? lower...upper : nil
    }

    private func selectionRects(for row: Int, rowFrame: NSRect) -> [NSRect] {
        guard let source, let text, let textSelection else { return [] }
        let normalized = textSelection.normalized
        let lineLength = text(source.line(at: row)).count

        let lowerColumn: Int
        let upperColumn: Int
        if row == normalized.lower.row && row == normalized.upper.row {
            lowerColumn = normalized.lower.column
            upperColumn = normalized.upper.column
        } else if row == normalized.lower.row {
            lowerColumn = normalized.lower.column
            upperColumn = lineLength
        } else if row == normalized.upper.row {
            lowerColumn = 0
            upperColumn = normalized.upper.column
        } else {
            lowerColumn = 0
            upperColumn = lineLength
        }

        return selectionRects(
            lowerColumn: min(lowerColumn, upperColumn),
            upperColumn: max(lowerColumn, upperColumn),
            rowFrame: rowFrame
        )
    }

    private func selectionRects(
        lowerColumn: Int,
        upperColumn: Int,
        rowFrame: NSRect
    ) -> [NSRect] {
        let characterWidth = max(hostConfiguration.selectionCharacterWidth, 1)
        let minimumWidth: CGFloat = lowerColumn == upperColumn ? 1 : 0

        switch hostConfiguration.wrapping {
        case .scroll:
            let minX = hostConfiguration.textInsets.leading + CGFloat(lowerColumn) * characterWidth
            let maxX = hostConfiguration.textInsets.leading + CGFloat(upperColumn) * characterWidth
            return [
                NSRect(
                    x: minX,
                    y: 0,
                    width: max(maxX - minX, minimumWidth),
                    height: rowFrame.height
                )
            ]
        case .wrap:
            let columnsPerLine = wrappedColumnsPerVisualLine(contentWidth: rowFrame.width)
            let firstVisualLine = lowerColumn / columnsPerLine
            let lastSelectedColumn = max(lowerColumn, upperColumn - 1)
            let lastVisualLine = lastSelectedColumn / columnsPerLine

            return (firstVisualLine...lastVisualLine).compactMap { visualLine in
                let lineStartColumn = visualLine * columnsPerLine
                let lineEndColumn = lineStartColumn + columnsPerLine
                let selectionStart = max(lowerColumn, lineStartColumn)
                let selectionEnd = min(upperColumn, lineEndColumn)

                guard selectionStart <= selectionEnd else { return nil }

                let x = hostConfiguration.textInsets.leading
                    + CGFloat(selectionStart - lineStartColumn) * characterWidth
                let width = max(
                    CGFloat(selectionEnd - selectionStart) * characterWidth,
                    minimumWidth
                )
                return NSRect(
                    x: x,
                    y: hostConfiguration.textInsets.top
                        + CGFloat(visualLine) * hostConfiguration.wrappedLineHeight,
                    width: width,
                    height: hostConfiguration.wrappedLineHeight
                )
            }
        }
    }

    private func selectedText(
        for textSelection: TextSelection,
        source: AnyLogSource<Line>
    ) -> String {
        guard let textProvider = text else { return "" }
        let normalized = textSelection.normalized
        if normalized.lower == normalized.upper {
            return ""
        }

        if normalized.lower.row == normalized.upper.row {
            let lineText = textProvider(source.line(at: normalized.lower.row))
            return substring(
                lineText,
                from: normalized.lower.column,
                to: normalized.upper.column
            )
        }

        var lines: [String] = []
        let firstText = textProvider(source.line(at: normalized.lower.row))
        lines.append(substring(firstText, from: normalized.lower.column, to: firstText.count))

        if normalized.upper.row > normalized.lower.row + 1 {
            for row in (normalized.lower.row + 1)..<normalized.upper.row {
                lines.append(textProvider(source.line(at: row)))
            }
        }

        let lastText = textProvider(source.line(at: normalized.upper.row))
        lines.append(substring(lastText, from: 0, to: normalized.upper.column))
        return lines.joined(separator: "\n")
    }

    private func substring(_ text: String, from lowerBound: Int, to upperBound: Int) -> String {
        let lower = min(max(lowerBound, 0), text.count)
        let upper = min(max(upperBound, lower), text.count)
        let start = text.index(text.startIndex, offsetBy: lower)
        let end = text.index(text.startIndex, offsetBy: upper)
        return String(text[start..<end])
    }

    private func updateFrameSize(viewportSize: NSSize) {
        let contentHeight = max(viewportSize.height, logContentHeight)
        let contentWidth = contentWidth(for: viewportSize)
        setFrameSize(NSSize(width: contentWidth, height: contentHeight))
    }

    private var logContentHeight: CGFloat {
        switch hostConfiguration.wrapping {
        case .scroll:
            return CGFloat(displayCount) * hostConfiguration.rowHeight
        case .wrap:
            guard displayCount > 0 else { return 0 }
            guard let lastOffset = rowOffsets.last, let lastHeight = rowHeights.last else {
                return 0
            }
            return lastOffset + lastHeight
        }
    }

    private func contentWidth(for viewportSize: NSSize) -> CGFloat {
        switch hostConfiguration.wrapping {
        case .scroll:
            return max(viewportSize.width, hostConfiguration.minimumContentWidth)
        case .wrap:
            return max(viewportSize.width, 1)
        }
    }

    private func rebuildRowMetricsIfNeeded(viewportSize: NSSize) {
        guard let source, let text else {
            rowHeights.removeAll(keepingCapacity: false)
            rowOffsets.removeAll(keepingCapacity: false)
            cachedRowMetricsCount = 0
            cachedSourceIdentifier = nil
            return
        }

        let count = source.numberOfLines
        let width = contentWidth(for: viewportSize)
        let sourceIdentifier = ObjectIdentifier(source)

        guard hostConfiguration.wrapping == .wrap else {
            rowHeights.removeAll(keepingCapacity: true)
            rowOffsets.removeAll(keepingCapacity: true)
            cachedRowMetricsWidth = width
            cachedRowMetricsCount = count
            cachedWrapping = hostConfiguration.wrapping
            cachedSourceIdentifier = sourceIdentifier
            return
        }

        guard cachedRowMetricsWidth != width
            || cachedRowMetricsCount != count
            || cachedWrapping != hostConfiguration.wrapping
            || cachedSourceIdentifier != sourceIdentifier
        else {
            return
        }

        var nextOffsets: [CGFloat] = []
        var nextHeights: [CGFloat] = []
        nextOffsets.reserveCapacity(count)
        nextHeights.reserveCapacity(count)

        var offset: CGFloat = 0
        for index in 0..<count {
            let line = source.line(at: index)
            let height = wrappedRowHeight(for: text(line), contentWidth: width)
            nextOffsets.append(offset)
            nextHeights.append(height)
            offset += height
        }

        rowOffsets = nextOffsets
        rowHeights = nextHeights
        cachedRowMetricsWidth = width
        cachedRowMetricsCount = count
        cachedWrapping = hostConfiguration.wrapping
        cachedSourceIdentifier = sourceIdentifier
    }

    private func visibleRowRange(dirtyRect: NSRect) -> Range<Int> {
        switch hostConfiguration.wrapping {
        case .scroll:
            return VirtualLogLayout.visibleRowRange(
                dirtyRect: dirtyRect,
                rowHeight: hostConfiguration.rowHeight,
                verticalPadding: 0,
                rowCount: displayCount
            )
        case .wrap:
            guard displayCount > 0,
                  rowOffsets.count == displayCount,
                  rowHeights.count == displayCount
            else {
                return 0..<0
            }

            let first = firstWrappedRowIntersecting(minY: dirtyRect.minY)
            let last = firstWrappedRowStarting(atOrAfter: dirtyRect.maxY)
            guard first < last else { return 0..<0 }
            return first..<last
        }
    }

    private func rowIndex(atY y: CGFloat) -> Int {
        guard displayCount > 0 else { return 0 }
        switch hostConfiguration.wrapping {
        case .scroll:
            let unclampedIndex = Int(floor(y / hostConfiguration.rowHeight))
            return min(max(unclampedIndex, 0), displayCount - 1)
        case .wrap:
            return min(max(firstWrappedRowIntersecting(minY: y), 0), displayCount - 1)
        }
    }

    private func rowOffset(for displayIndex: Int) -> CGFloat {
        switch hostConfiguration.wrapping {
        case .scroll:
            return CGFloat(displayIndex) * hostConfiguration.rowHeight
        case .wrap:
            guard rowOffsets.indices.contains(displayIndex) else {
                return CGFloat(displayIndex) * hostConfiguration.rowHeight
            }
            return rowOffsets[displayIndex]
        }
    }

    private func rowHeight(for displayIndex: Int) -> CGFloat {
        switch hostConfiguration.wrapping {
        case .scroll:
            return hostConfiguration.rowHeight
        case .wrap:
            guard rowHeights.indices.contains(displayIndex) else {
                return hostConfiguration.wrappedLineHeight
            }
            return rowHeights[displayIndex]
        }
    }

    private func firstWrappedRowIntersecting(minY: CGFloat) -> Int {
        var low = 0
        var high = displayCount

        while low < high {
            let mid = (low + high) / 2
            if rowOffsets[mid] + rowHeights[mid] <= minY {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private func firstWrappedRowStarting(atOrAfter maxY: CGFloat) -> Int {
        var low = 0
        var high = displayCount

        while low < high {
            let mid = (low + high) / 2
            if rowOffsets[mid] < maxY {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private func wrappedRowHeight(for text: String, contentWidth: CGFloat) -> CGFloat {
        let columnsPerLine = wrappedColumnsPerVisualLine(contentWidth: contentWidth)
        let visualLineCount = max(1, Int(ceil(Double(text.count) / Double(columnsPerLine))))
        return hostConfiguration.textInsets.top
            + CGFloat(visualLineCount) * hostConfiguration.wrappedLineHeight
            + hostConfiguration.textInsets.bottom
    }

    private func wrappedColumnsPerVisualLine(contentWidth: CGFloat) -> Int {
        let characterWidth = max(hostConfiguration.selectionCharacterWidth, 1)
        let horizontalInsets = hostConfiguration.textInsets.leading + hostConfiguration.textInsets.trailing
        let textWidth = max(1, contentWidth - horizontalInsets)
        return max(1, Int(floor(textWidth / characterWidth)))
    }
}

private final class LogRowHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class SelectionOverlayView: NSView {
    var selectionRects: [NSRect] = [] {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.selectedTextBackgroundColor.withAlphaComponent(0.28).setFill()
        for rect in selectionRects where rect.intersects(dirtyRect) {
            rect.fill()
        }
    }
}

enum VirtualLogLayout {
    static func visibleRowRange(
        dirtyRect: NSRect,
        rowHeight: CGFloat,
        verticalPadding: CGFloat,
        rowCount: Int
    ) -> Range<Int> {
        guard rowCount > 0, rowHeight > 0 else { return 0..<0 }

        let first = max(
            0,
            Int(floor((dirtyRect.minY - verticalPadding) / rowHeight))
        )
        let last = min(
            rowCount,
            Int(ceil((dirtyRect.maxY - verticalPadding) / rowHeight)) + 1
        )

        guard first < last else { return 0..<0 }
        return first..<last
    }
}
