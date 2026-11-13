#if os(iOS)

import XCTest
@testable import KVKCalendar

final class AllDayCollapseTests: XCTestCase {
    
    private func makeEvent(_ id: String) -> Event {
        var event = Event(ID: id)
        event.isAllDay = true
        return event
    }
    
    private func prepare(_ columns: [[String]]) -> [AllDayView.PrepareEvents] {
        columns.enumerated().map { (idx, ids) in
            AllDayView.PrepareEvents(events: ids.map(makeEvent), date: nil, xOffset: CGFloat(idx) * 50, width: 50)
        }
    }
    
    func testWeekWithoutLimitIsNotCollapsible() {
        let info = AllDayView.collapseInfo(prepareEvents: prepare([["1", "2", "3", "4"]]), type: .week, maxRows: nil)
        XCTAssertEqual(info.totalRows, 4)
        XCTAssertEqual(info.visibleRows, 4)
        XCTAssertFalse(info.isCollapsible)
    }
    
    func testWeekFitsInLimit() {
        let info = AllDayView.collapseInfo(prepareEvents: prepare([["1", "2"], ["3"]]), type: .week, maxRows: 2)
        XCTAssertEqual(info.visibleRows, 2)
        XCTAssertFalse(info.isCollapsible)
    }
    
    func testWeekCountsHiddenMultiDayEventOnce() {
        // "3" spans two days and is hidden in both columns
        let info = AllDayView.collapseInfo(prepareEvents: prepare([["1", "2", "3", "4"], ["1", "2", "3"]]),
                                           type: .week, maxRows: 2)
        XCTAssertEqual(info.totalRows, 4)
        XCTAssertEqual(info.visibleRows, 2)
        XCTAssertEqual(info.hiddenCount, 2)
    }
    
    func testWeekDoesNotCountEventVisibleInAnotherColumn() {
        // "3" is visible in the second column, so only "4" is hidden
        let info = AllDayView.collapseInfo(prepareEvents: prepare([["1", "2", "3", "4"], ["3"]]),
                                           type: .week, maxRows: 2)
        XCTAssertEqual(info.hiddenCount, 1)
        XCTAssertTrue(info.isCollapsible)
    }
    
    func testWeekNotCollapsibleWhenAllHiddenEventsAreVisibleElsewhere() {
        let info = AllDayView.collapseInfo(prepareEvents: prepare([["1", "2", "3"], ["3"]]),
                                           type: .week, maxRows: 2)
        XCTAssertEqual(info.hiddenCount, 0)
        XCTAssertEqual(info.visibleRows, 3)
        XCTAssertFalse(info.isCollapsible)
    }
    
    func testDayUsesTwoEventsPerRow() {
        let info = AllDayView.collapseInfo(prepareEvents: prepare([["1", "2", "3", "4", "5", "6", "7"]]),
                                           type: .day, maxRows: 2)
        XCTAssertEqual(info.totalRows, 4)
        XCTAssertEqual(info.visibleRows, 2)
        XCTAssertEqual(info.hiddenCount, 3)
    }
    
}

#endif
