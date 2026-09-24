@testable import hunch
import XCTest

final class AppendBlocksCommandTests: XCTestCase {
    func testAppendBlocksCommandParsesBlocksFlag() throws {
        let cmd = try AppendBlocksCommand.parse(["someId", "--blocks", "{\"children\":[]}"])
        XCTAssertEqual(cmd.blocks, "{\"children\":[]}")
        XCTAssertEqual(cmd.blockId, "someId")
    }

    func testAppendBlocksCommandParsesShortFlag() throws {
        let cmd = try AppendBlocksCommand.parse(["someId", "-b", "{\"children\":[]}"])
        XCTAssertEqual(cmd.blocks, "{\"children\":[]}")
        XCTAssertEqual(cmd.blockId, "someId")
    }

    func testAppendBlocksCommandDefaultsToNil() throws {
        let cmd = try AppendBlocksCommand.parse(["someId"])
        XCTAssertNil(cmd.blocks)
        XCTAssertNil(cmd.after)
    }

    func testAppendBlocksCommandParsesAfter() throws {
        let cmd = try AppendBlocksCommand.parse(["parentId", "--after", "siblingId", "--blocks", "[]"])
        XCTAssertEqual(cmd.blockId, "parentId")
        XCTAssertEqual(cmd.after, "siblingId")
    }

    // MARK: - Request Body

    func testRequestBodyWithoutAfterOnlyWraps() throws {
        let input = Data(#"[{"type":"paragraph"}]"#.utf8)
        let body = try AppendBlocksCommand.requestBody(from: input, after: nil)
        XCTAssertEqual(body, JSONChildrenWrapper.wrapIfNeeded(input))
    }

    func testRequestBodyAddsAfterToBareArray() throws {
        let input = Data(#"[{"type":"paragraph"}]"#.utf8)
        let body = try AppendBlocksCommand.requestBody(from: input, after: "siblingId")

        let parsed = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(parsed?["after"] as? String, "siblingId")
        XCTAssertEqual((parsed?["children"] as? [Any])?.count, 1)
        XCTAssertNil(parsed?["position"])
    }

    func testRequestBodyAddsAfterToWrappedObject() throws {
        let input = Data(#"{"children":[{"type":"paragraph"},{"type":"divider"}]}"#.utf8)
        let body = try AppendBlocksCommand.requestBody(from: input, after: "siblingId")

        let parsed = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(parsed?["after"] as? String, "siblingId")
        XCTAssertEqual((parsed?["children"] as? [Any])?.count, 2)
    }

    func testRequestBodyRejectsAfterGivenTwice() {
        let input = Data(#"{"children":[],"after":"otherId"}"#.utf8)
        XCTAssertThrowsError(try AppendBlocksCommand.requestBody(from: input, after: "siblingId"))
    }

    func testRequestBodyRejectsAfterWithPosition() {
        let input = Data(#"{"children":[],"position":{"type":"start"}}"#.utf8)
        XCTAssertThrowsError(try AppendBlocksCommand.requestBody(from: input, after: "siblingId"))
    }

    func testRequestBodyRejectsSingleBlockObject() {
        // A lone block is not wrapped, so it would reach Notion as a body with no children
        let input = Data(#"{"type":"paragraph","paragraph":{"rich_text":[]}}"#.utf8)
        XCTAssertThrowsError(try AppendBlocksCommand.requestBody(from: input, after: nil))
    }

    func testRequestBodyRejectsEmptyInput() {
        XCTAssertThrowsError(try AppendBlocksCommand.requestBody(from: Data(), after: nil))
    }

    func testRequestBodyRejectsObjectWithoutChildrenWithAfter() {
        let input = Data(#"{"blocks":[]}"#.utf8)
        XCTAssertThrowsError(try AppendBlocksCommand.requestBody(from: input, after: "siblingId"))
    }

    func testRequestBodyRejectsInvalidJSONWithAfter() {
        let input = Data("not json".utf8)
        XCTAssertThrowsError(try AppendBlocksCommand.requestBody(from: input, after: "siblingId"))
    }
}
