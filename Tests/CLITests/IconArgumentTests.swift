import ArgumentParser
import HunchKit
@testable import hunch
import XCTest

final class IconArgumentTests: XCTestCase {
    func testEmojiBecomesAnEmojiIcon() throws {
        let icon = try IconArgument.icon(from: "🐞")
        XCTAssertEqual(icon.type, "emoji")
        XCTAssertEqual(icon.emoji, "🐞")
    }

    func testSurroundingWhitespaceIsIgnored() throws {
        XCTAssertEqual(try IconArgument.icon(from: " 🐞\n").emoji, "🐞")
    }

    func testURLBecomesAnExternalIcon() throws {
        let icon = try IconArgument.icon(from: "https://example.com/icon.png")
        XCTAssertEqual(icon.type, "external")
        XCTAssertEqual(icon.external?.url, "https://example.com/icon.png")
        XCTAssertNil(icon.emoji)
    }

    func testJSONBecomesANativeIcon() throws {
        let icon = try IconArgument.icon(from: #"{"type":"icon","icon":{"name":"pizza","color":"blue"}}"#)
        XCTAssertEqual(icon.type, "icon")
        XCTAssertEqual(icon.native?.name, "pizza")
        XCTAssertEqual(icon.native?.color, "blue")
    }

    func testJSONBecomesACustomEmojiIcon() throws {
        let icon = try IconArgument.icon(from: #"{"type":"custom_emoji","custom_emoji":{"id":"45ce454c"}}"#)
        XCTAssertEqual(icon.type, "custom_emoji")
        XCTAssertEqual(icon.customEmoji?.id, "45ce454c")
    }

    func testJSONThatIsNotAnIconIsRejected() {
        XCTAssertThrowsError(try IconArgument.icon(from: #"{"name":"pizza"}"#)) { error in
            let message = (error as? ValidationError)?.message ?? ""
            XCTAssertTrue(message.hasPrefix("The --icon JSON must be an icon object"), message)
        }
        XCTAssertThrowsError(try IconArgument.icon(from: #"{"type":"#))
    }

    func testEmptyIconIsRejected() {
        XCTAssertThrowsError(try IconArgument.icon(from: " "))
    }

    // MARK: - Commands

    func testCreatePageParsesIcon() throws {
        let cmd = try CreatePageCommand.parse(["--database", "dbId", "--icon", "🐞"])
        XCTAssertEqual(cmd.icon, "🐞")
    }

    func testUpdatePageParsesIconOptions() throws {
        XCTAssertEqual(try UpdatePageCommand.parse(["pageId", "--icon", "🐞"]).icon, "🐞")
        XCTAssertTrue(try UpdatePageCommand.parse(["pageId", "--remove-icon"]).removeIcon)
    }

    func testUpdatePageSetsTheIcon() throws {
        guard case .set(let icon) = try UpdatePageCommand.iconUpdate(icon: "🐞", removeIcon: false) else {
            return XCTFail("Expected the icon to be set")
        }
        XCTAssertEqual(icon.emoji, "🐞")
    }

    func testUpdatePageRemovesTheIcon() throws {
        guard case .remove = try UpdatePageCommand.iconUpdate(icon: nil, removeIcon: true) else {
            return XCTFail("Expected the icon to be removed")
        }
    }

    func testUpdatePageLeavesTheIconWithoutIconOptions() throws {
        XCTAssertNil(try UpdatePageCommand.iconUpdate(icon: nil, removeIcon: false))
    }

    func testUpdatePageRejectsSettingAndRemovingTheIcon() {
        XCTAssertThrowsError(try UpdatePageCommand.iconUpdate(icon: "🐞", removeIcon: true)) { error in
            XCTAssertEqual((error as? ValidationError)?.message, "Give --icon or --remove-icon, not both")
        }
    }
}
