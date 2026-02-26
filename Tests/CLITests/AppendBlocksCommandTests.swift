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
    }
}
