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

    // MARK: - Update Page Body

    private func object(_ body: NotionAPI.UpdatePageBody) throws -> NSDictionary {
        return try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as! NSDictionary
    }

    func testUpdatePageBodySetsTheIcon() throws {
        let body = NotionAPI.UpdatePageBody(properties: nil, archived: nil, icon: .set(.emoji("🐞")))
        XCTAssertEqual(try object(body), ["icon": ["type": "emoji", "emoji": "🐞"]] as NSDictionary)
    }

    func testUpdatePageBodyRemovesTheIconWithNull() throws {
        let body = NotionAPI.UpdatePageBody(properties: nil, archived: nil, icon: .remove)
        XCTAssertEqual(try object(body), ["icon": NSNull()] as NSDictionary)
    }

    func testUpdatePageBodyLeavesOutAnUnchangedIcon() throws {
        let body = NotionAPI.UpdatePageBody(properties: nil, archived: true, icon: nil)
        XCTAssertEqual(try object(body), ["archived": true] as NSDictionary)
    }
}
