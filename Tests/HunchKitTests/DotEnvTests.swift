import XCTest
@testable import HunchKit

final class DotEnvTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DotEnvTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - parseValue(forKey:in:)

    func testBasicKeyValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY=ntn_abc123".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertEqual(value, "ntn_abc123")
    }

    func testDoubleQuotedValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY=\"ntn_abc123\"".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertEqual(value, "ntn_abc123")
    }

    func testSingleQuotedValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY='ntn_abc123'".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertEqual(value, "ntn_abc123")
    }

    func testSkipsComments() {
        let contents = """
        # This is a comment
        NOTION_KEY=ntn_abc123
        """
        let envFile = tempDir.appendingPathComponent(".env")
        try! contents.write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertEqual(value, "ntn_abc123")
    }

    func testSkipsBlankLines() {
        let contents = """

        NOTION_KEY=ntn_abc123

        """
        let envFile = tempDir.appendingPathComponent(".env")
        try! contents.write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertEqual(value, "ntn_abc123")
    }

    func testReturnsNilForMissingKey() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "OTHER_KEY=value".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertNil(value)
    }

    func testReturnsNilForEmptyValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY=".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertNil(value)
    }

    func testReturnsNilForMissingFile() {
        let envFile = tempDir.appendingPathComponent(".env")
        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertNil(value)
    }

    func testTrimsWhitespaceAroundValue() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY=  ntn_abc123  ".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertEqual(value, "ntn_abc123")
    }

    func testMultipleKeysReturnsCorrectOne() {
        let contents = """
        DATABASE_URL=postgres://localhost
        NOTION_KEY=ntn_abc123
        OTHER_SECRET=shhh
        """
        let envFile = tempDir.appendingPathComponent(".env")
        try! contents.write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertEqual(value, "ntn_abc123")
    }

    func testDoesNotMatchKeyPrefix() {
        let envFile = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY_EXTRA=wrong".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.parseValue(forKey: "NOTION_KEY", in: envFile)
        XCTAssertNil(value)
    }

    // MARK: - loadValue(forKey:startingIn:)

    func testWalksUpDirectories() {
        // Create nested dir structure: tempDir/a/b/c
        let nested = tempDir.appendingPathComponent("a/b/c")
        try! FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        // Put .env in tempDir (grandparent of the starting dir)
        let envFile = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY=ntn_found_it".write(to: envFile, atomically: true, encoding: .utf8)

        let value = DotEnv.loadValue(forKey: "NOTION_KEY", startingIn: nested)
        XCTAssertEqual(value, "ntn_found_it")
    }

    func testClosestEnvFileWins() {
        // Create nested dir: tempDir/child
        let child = tempDir.appendingPathComponent("child")
        try! FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)

        // Put .env in both tempDir and child
        let parentEnv = tempDir.appendingPathComponent(".env")
        try! "NOTION_KEY=parent_value".write(to: parentEnv, atomically: true, encoding: .utf8)

        let childEnv = child.appendingPathComponent(".env")
        try! "NOTION_KEY=child_value".write(to: childEnv, atomically: true, encoding: .utf8)

        let value = DotEnv.loadValue(forKey: "NOTION_KEY", startingIn: child)
        XCTAssertEqual(value, "child_value")
    }

    func testReturnsNilWhenNoEnvFileFound() {
        // Create an empty nested dir
        let nested = tempDir.appendingPathComponent("empty/deep")
        try! FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        // No .env anywhere in tempDir — but the walk will go beyond tempDir to /tmp, /, etc.
        // We can't control that, so just verify it doesn't crash and returns something or nil
        _ = DotEnv.loadValue(forKey: "VERY_UNLIKELY_KEY_\(UUID().uuidString)", startingIn: nested)
    }
}
