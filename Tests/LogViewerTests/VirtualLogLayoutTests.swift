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

    @Test
    func wrappedMetricsRowCountClampsToAvailableMetrics() {
        let rowCount = VirtualLogLayout.wrappedMetricsRowCount(
            displayCount: 10,
            rowOffsets: [0, 20, 40],
            rowHeights: [20, 20]
        )

        #expect(rowCount == 2)
    }

    @Test
    func firstWrappedRowIntersectingClampsStaleRowCount() {
        let row = VirtualLogLayout.firstWrappedRowIntersecting(
            minY: 45,
            rowCount: 10,
            rowOffsets: [0, 20, 40],
            rowHeights: [20, 20, 20]
        )

        #expect(row == 2)
    }

    @Test
    func firstWrappedRowStartingClampsStaleRowCount() {
        let row = VirtualLogLayout.firstWrappedRowStarting(
            atOrAfter: 45,
            rowCount: 10,
            rowOffsets: [0, 20, 40]
        )

        #expect(row == 3)
    }

    @Test
    func clampedVisibleRectClampsInfiniteHeightToContentHeight() {
        let visibleRect = VirtualLogLayout.clampedVisibleRect(
            .infinite,
            contentHeight: 12_000
        )

        #expect(visibleRect.height == 12_000)
        #expect(visibleRect.minY == 0)
        #expect(visibleRect.maxY == 12_000)
    }

    @Test
    func visibleRowRangeStaysFiniteForInfiniteViewport() {
        let visibleRect = VirtualLogLayout.clampedVisibleRect(
            .infinite,
            contentHeight: 12_000
        )
        let range = VirtualLogLayout.visibleRowRange(
            dirtyRect: visibleRect,
            rowHeight: 24,
            verticalPadding: 0,
            rowCount: 500
        )

        #expect(range.lowerBound == 0)
        #expect(range.upperBound == 500)
    }
}
