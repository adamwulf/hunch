import ArgumentParser
@testable import hunch
import XCTest

final class JSONInputTests: XCTestCase {
    private func missingInputMessage(
        _ expression: @autoclosure () throws -> Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        do {
            _ = try expression()
            XCTFail("Expected missing input to be refused", file: file, line: line)
            return ""
        } catch {
            return (error as? ValidationError)?.message ?? ""
        }
    }

    func testOptionJSONIsUsedAsIs() throws {
        let data = try readJSONInput(#"{"to_do":{"checked":true}}"#, option: "--block", stdinIsTerminal: true, readStdin: {
            XCTFail("Stdin should not be read when the option is given")
            return Data()
        })
        XCTAssertEqual(data, Data(#"{"to_do":{"checked":true}}"#.utf8))
    }

    func testEmptyOptionIsMissingInput() {
        let message = missingInputMessage(try readJSONInput("", option: "--blocks", stdinIsTerminal: false, readStdin: { Data() }))
        XCTAssertEqual(message, "Give the JSON with --blocks or on stdin")
    }

    func testTerminalStdinIsMissingInputWithoutWaiting() {
        let message = missingInputMessage(try readJSONInput(nil, option: "--block", stdinIsTerminal: true, readStdin: {
            XCTFail("A terminal should not be read, because it would wait for input")
            return Data()
        }))
        XCTAssertEqual(message, "Give the JSON with --block or on stdin")
    }

    func testEmptyStdinIsMissingInput() {
        let message = missingInputMessage(try readJSONInput(nil, option: "--blocks", stdinIsTerminal: false, readStdin: { Data() }))
        XCTAssertEqual(message, "Give the JSON with --blocks or on stdin")
    }

    func testStdinIsReadAsBytes() throws {
        // A raw line break inside a JSON string is kept, so parsing reports it instead of it vanishing
        let input = Data("{\"paragraph\":\n{\"rich_text\":[{\"text\":{\"content\":\"a\nb\"}}]}}".utf8)
        let data = try readJSONInput(nil, option: "--block", stdinIsTerminal: false, readStdin: { input })
        XCTAssertEqual(data, input)
    }
}
