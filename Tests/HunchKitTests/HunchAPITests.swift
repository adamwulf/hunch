import XCTest
@testable import HunchKit

final class HunchAPITests: XCTestCase {

    // MARK: - Append Child Count

    func testChildCountCountsTheChildrenArray() {
        let body = Data(#"{"children":[{"type":"paragraph"},{"type":"divider"}],"after":"siblingId"}"#.utf8)
        XCTAssertEqual(HunchAPI.childCount(in: body), 2)
    }

    func testChildCountIsNilWithoutAChildrenArray() {
        XCTAssertNil(HunchAPI.childCount(in: Data(#"{"after":"siblingId"}"#.utf8)))
        XCTAssertNil(HunchAPI.childCount(in: Data(#"[{"type":"paragraph"}]"#.utf8)))
        XCTAssertNil(HunchAPI.childCount(in: Data()))
    }
}
