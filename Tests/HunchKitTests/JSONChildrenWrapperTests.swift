import XCTest
@testable import HunchKit

final class JSONChildrenWrapperTests: XCTestCase {

    func testBareArrayGetsWrapped() throws {
        let input = Data(#"[{"type":"paragraph"}]"#.utf8)
        let output = JSONChildrenWrapper.wrapIfNeeded(input)

        let parsed = try JSONSerialization.jsonObject(with: output) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertNotNil(parsed?["children"] as? [Any])

        let children = parsed?["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 1)
        XCTAssertEqual(children?.first?["type"] as? String, "paragraph")
    }

    func testAlreadyWrappedPassesThrough() throws {
        let input = Data(#"{"children":[{"type":"heading_1"}]}"#.utf8)
        let output = JSONChildrenWrapper.wrapIfNeeded(input)

        let parsed = try JSONSerialization.jsonObject(with: output) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertNotNil(parsed?["children"] as? [Any])

        let children = parsed?["children"] as? [[String: Any]]
        XCTAssertEqual(children?.count, 1)
        XCTAssertEqual(children?.first?["type"] as? String, "heading_1")
    }

    func testUnrelatedObjectPassesThrough() throws {
        let input = Data(#"{"blocks":[1,2,3]}"#.utf8)
        let output = JSONChildrenWrapper.wrapIfNeeded(input)

        let parsed = try JSONSerialization.jsonObject(with: output) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertNil(parsed?["children"])
        XCTAssertNotNil(parsed?["blocks"])
    }
}
