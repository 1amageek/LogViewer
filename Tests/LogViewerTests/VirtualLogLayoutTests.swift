import AppKit
import Testing
@testable import LogViewer

struct VirtualLogLayoutTests {
    @Test
    func visibleRowRangeReadsOnlyRowsIntersectingViewport() {
        let range = VirtualLogLayout.visibleRowRange(
            dirtyRect: NSRect(x: 0, y: 1_000, width: 800, height: 400),
            rowHeight: 20,
            verticalPadding: 10,
            rowCount: 1_000_000
        )

        #expect(range.lowerBound == 49)
        #expect(range.upperBound == 71)
        #expect(range.count == 22)
    }

    @Test
    func visibleRowRangeClampsToAvailableRows() {
        let visibleRect = VirtualLogLayout.clampedVisibleRect(
            NSRect(x: 0, y: 19_990, width: 800, height: 500),
            contentHeight: 20_010
        )
        let range = VirtualLogLayout.visibleRowRange(
            dirtyRect: visibleRect,
            rowHeight: 20,
            verticalPadding: 10,
            rowCount: 1_000
        )

        #expect(range.lowerBound == 975)
        #expect(range.upperBound == 1_000)
    }

    @Test
    func clampedVisibleRectKeepsBottomRowsVisibleDuringOverscroll() {
        let visibleRect = VirtualLogLayout.clampedVisibleRect(
            NSRect(x: 0, y: 19_990, width: 800, height: 500),
            contentHeight: 20_010
        )

        #expect(visibleRect.minY == 19_510)
        #expect(visibleRect.maxY == 20_010)
    }

    @Test
    func visibleRowRangeDoesNotGoEmptyWhenViewportStartsBelowContent() {
        let visibleRect = VirtualLogLayout.clampedVisibleRect(
            NSRect(x: 0, y: 20_500, width: 800, height: 500),
            contentHeight: 20_010
        )
        let range = VirtualLogLayout.visibleRowRange(
            dirtyRect: visibleRect,
            rowHeight: 20,
            verticalPadding: 10,
            rowCount: 1_000
        )

        #expect(range.lowerBound == 975)
        #expect(range.upperBound == 1_000)
    }

    @Test
    func visibleRowRangeReturnsEmptyForNoRows() {
        let range = VirtualLogLayout.visibleRowRange(
            dirtyRect: NSRect(x: 0, y: 0, width: 800, height: 500),
            rowHeight: 20,
            verticalPadding: 10,
            rowCount: 0
        )

        #expect(range.isEmpty)
    }
}
