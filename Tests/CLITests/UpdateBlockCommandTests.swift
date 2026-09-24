import ArgumentParser
@testable import hunch
import XCTest

final class UpdateBlockCommandTests: XCTestCase {
    func testUpdateBlockCommandParsesBlockFlag() throws {
        let cmd = try UpdateBlockCommand.parse(["someId", "--block", #"{"to_do":{"checked":true}}"#])
        XCTAssertEqual(cmd.blockId, "someId")
        XCTAssertEqual(cmd.block, #"{"to_do":{"checked":true}}"#)
    }

    func testUpdateBlockCommandParsesShortFlag() throws {
        let cmd = try UpdateBlockCommand.parse(["someId", "-b", "{}"])
        XCTAssertEqual(cmd.block, "{}")
    }

    func testUpdateBlockCommandDefaultsToNil() throws {
        let cmd = try UpdateBlockCommand.parse(["someId"])
        XCTAssertNil(cmd.block)
    }

    func testRequestBodyPassesObjectThrough() throws {
        let input = Data(#"{"code":{"language":"swift"}}"#.utf8)
        XCTAssertEqual(try UpdateBlockCommand.requestBody(from: input), input)
    }

    func testRequestBodyRejectsArray() {
        let input = Data(#"[{"to_do":{"checked":true}}]"#.utf8)
        XCTAssertThrowsError(try UpdateBlockCommand.requestBody(from: input))
    }

    func testRequestBodyRejectsInvalidJSON() {
        let input = Data(#"{"to_do":"#.utf8)
        XCTAssertThrowsError(try UpdateBlockCommand.requestBody(from: input)) { error in
            // A syntax error says so, instead of claiming the JSON has the wrong shape
            let message = (error as? ValidationError)?.message ?? ""
            XCTAssertTrue(message.hasPrefix("The input is not valid JSON"), message)
        }
    }

    func testRequestBodyRejectsEmptyInput() {
        XCTAssertThrowsError(try UpdateBlockCommand.requestBody(from: Data())) { error in
            let message = (error as? ValidationError)?.message ?? ""
            XCTAssertTrue(message.hasPrefix("The input is not valid JSON"), message)
        }
    }

    func testRequestBodyRejectsRawLineBreakInsideString() {
        let input = Data("{\"paragraph\":{\"rich_text\":[{\"text\":{\"content\":\"a\nb\"}}]}}".utf8)
        XCTAssertThrowsError(try UpdateBlockCommand.requestBody(from: input))
    }
}
