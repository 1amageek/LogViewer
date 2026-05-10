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
        let range = VirtualLogLayout.visibleRowRange(
            dirtyRect: NSRect(x: 0, y: 19_990, width: 800, height: 500),
            rowHeight: 20,
            verticalPadding: 10,
            rowCount: 1_000
        )

        #expect(range.lowerBound == 999)
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
