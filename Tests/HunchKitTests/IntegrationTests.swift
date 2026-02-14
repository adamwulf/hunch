import XCTest
@testable import HunchKit
import OSLog

/// Integration tests that hit the real Notion API to diagnose decoding failures.
/// Skipped when no .env file with NOTION_KEY is found.
final class IntegrationTests: XCTestCase {

    /// Captured raw JSON responses keyed by API path
    static var capturedResponses: [(path: String, json: String)] = []

    override func setUp() async throws {
        try await super.setUp()

        guard let token = Self.loadNotionKey() else {
            throw XCTSkip("No .env file with NOTION_KEY found — skipping integration tests")
        }

        NotionAPI.shared.token = token
        Self.capturedResponses = []

        // Install log handler to capture raw JSON responses
        NotionAPI.logHandler = { level, message, context in
            if level == .debug && context == nil && message.hasPrefix("{") || message.hasPrefix("[") {
                // This is the raw JSON body log line
                let path = Self.capturedResponses.last?.path ?? "unknown"
                Self.capturedResponses.append((path: path, json: message))
            } else if level == .debug, let ctx = context, let path = ctx["path"] as? String {
                Self.capturedResponses.append((path: path, json: ""))
            }
        }
    }

    override func tearDown() async throws {
        NotionAPI.logHandler = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Loads NOTION_KEY from .env file, searching up from the test bundle
    static func loadNotionKey() -> String? {
        // Try multiple locations for the .env file
        let candidates = [
            // Package root (when running swift test from repo root)
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Tests/HunchKitTests/
                .deletingLastPathComponent() // Tests/
                .deletingLastPathComponent() // repo root
                .appendingPathComponent(".env"),
            // Direct path if known
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".env")
        ]

        for envURL in candidates {
            if let contents = try? String(contentsOf: envURL, encoding: .utf8) {
                for line in contents.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("NOTION_KEY=") {
                        let value = String(trimmed.dropFirst("NOTION_KEY=".count))
                        if !value.isEmpty {
                            return value
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Extracts the underlying DecodingError from the HunchAPI error chain
    static func extractDecodingError(from error: Error) -> DecodingError? {
        if let decodingError = error as? DecodingError {
            return decodingError
        }
        if let hunchError = error as? HunchAPIError {
            if case .apiError(let serviceError) = hunchError {
                if case .decodeError(let inner) = serviceError {
                    return inner as? DecodingError
                }
            }
        }
        return nil
    }

    /// Prints detailed info about a DecodingError
    static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
            return "TYPE MISMATCH: Expected \(type) at path '\(path)' — \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
            return "VALUE NOT FOUND: \(type) at path '\(path)' — \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            let path = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
            return "KEY NOT FOUND: '\(key.stringValue)' at path '\(path)' — \(context.debugDescription)"
        case .dataCorrupted(let context):
            let path = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
            return "DATA CORRUPTED at path '\(path)' — \(context.debugDescription)"
        @unknown default:
            return "UNKNOWN DecodingError: \(error)"
        }
    }

    /// Prints the last captured raw JSON (truncated)
    static func printLastResponse(label: String) {
        guard let last = capturedResponses.last, !last.json.isEmpty else {
            print("[\(label)] No raw JSON captured")
            return
        }
        let truncated = last.json.prefix(2000)
        print("[\(label)] Raw JSON (\(last.json.count) chars, path: \(last.path)):")
        print(truncated)
        if last.json.count > 2000 {
            print("... (truncated)")
        }
    }

    // MARK: - Integration Tests

    func testFetchDatabases() async throws {
        print("\n=== testFetchDatabases ===")
        do {
            let databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 3)
            print("SUCCESS: Fetched \(databases.count) databases")
            for db in databases {
                print("  - \(db.id): \(db.description)")
            }
            XCTAssertGreaterThan(databases.count, 0, "Expected at least one database")
        } catch {
            Self.printLastResponse(label: "fetchDatabases")
            if let decodingError = Self.extractDecodingError(from: error) {
                let desc = Self.describeDecodingError(decodingError)
                XCTFail("Decoding failed in fetchDatabases: \(desc)")
            } else {
                XCTFail("fetchDatabases failed: \(error)")
            }
        }
    }

    func testFetchPages() async throws {
        print("\n=== testFetchPages ===")

        // First get a database
        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 1)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found to query pages from")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            Self.printLastResponse(label: "fetchDatabases-for-pages")
            if let decodingError = Self.extractDecodingError(from: error) {
                XCTFail("Decoding failed fetching databases: \(Self.describeDecodingError(decodingError))")
            } else {
                XCTFail("Failed to fetch databases for page query: \(error)")
            }
            return
        }

        let databaseId = databases[0].id
        print("Using database: \(databaseId) (\(databases[0].description))")

        do {
            let pages = try await HunchAPI.shared.fetchPages(databaseId: databaseId, limit: 3)
            print("SUCCESS: Fetched \(pages.count) pages")
            for page in pages {
                print("  - \(page.id): \(page.description)")
                // Print property types to help diagnose issues
                for (name, prop) in page.properties {
                    print("    prop '\(name)': \(prop.kind)")
                }
            }
        } catch {
            Self.printLastResponse(label: "fetchPages")
            if let decodingError = Self.extractDecodingError(from: error) {
                let desc = Self.describeDecodingError(decodingError)
                XCTFail("Decoding failed in fetchPages: \(desc)")
            } else {
                XCTFail("fetchPages failed: \(error)")
            }
        }
    }

    func testRetrievePage() async throws {
        print("\n=== testRetrievePage ===")

        // Get a page ID first
        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 1)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        let pages: [Page]
        do {
            pages = try await HunchAPI.shared.fetchPages(databaseId: databases[0].id, limit: 1)
            guard !pages.isEmpty else {
                throw XCTSkip("No pages found in database")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            Self.printLastResponse(label: "fetchPages-for-retrieve")
            if let decodingError = Self.extractDecodingError(from: error) {
                XCTFail("Decoding failed fetching pages: \(Self.describeDecodingError(decodingError))")
            } else {
                XCTFail("Failed to fetch pages: \(error)")
            }
            return
        }

        let pageId = pages[0].id
        print("Retrieving page: \(pageId)")

        do {
            let page = try await HunchAPI.shared.retrievePage(pageId: pageId)
            print("SUCCESS: Retrieved page '\(page.description)'")
            print("  properties: \(page.properties.keys.sorted().joined(separator: ", "))")
        } catch {
            Self.printLastResponse(label: "retrievePage")
            if let decodingError = Self.extractDecodingError(from: error) {
                let desc = Self.describeDecodingError(decodingError)
                XCTFail("Decoding failed in retrievePage: \(desc)")
            } else {
                XCTFail("retrievePage failed: \(error)")
            }
        }
    }

    func testFetchBlocks() async throws {
        print("\n=== testFetchBlocks ===")

        // Get a page ID first
        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 1)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        let pages: [Page]
        do {
            pages = try await HunchAPI.shared.fetchPages(databaseId: databases[0].id, limit: 1)
            guard !pages.isEmpty else {
                throw XCTSkip("No pages found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            Self.printLastResponse(label: "fetchPages-for-blocks")
            if let decodingError = Self.extractDecodingError(from: error) {
                XCTFail("Decoding failed: \(Self.describeDecodingError(decodingError))")
            } else {
                XCTFail("Failed to fetch pages: \(error)")
            }
            return
        }

        let pageId = pages[0].id
        print("Fetching blocks for page: \(pageId)")

        do {
            let blocks = try await HunchAPI.shared.fetchBlocks(in: pageId)
            print("SUCCESS: Fetched \(blocks.count) blocks")
            for block in blocks {
                print("  - \(block.type.rawValue) (\(block.id))")
                if !block.children.isEmpty {
                    for child in block.children {
                        print("    - \(child.type.rawValue) (\(child.id))")
                    }
                }
            }
        } catch {
            Self.printLastResponse(label: "fetchBlocks")
            if let decodingError = Self.extractDecodingError(from: error) {
                let desc = Self.describeDecodingError(decodingError)
                XCTFail("Decoding failed in fetchBlocks: \(desc)")
            } else {
                XCTFail("fetchBlocks failed: \(error)")
            }
        }
    }

    func testSearch() async throws {
        print("\n=== testSearch ===")
        do {
            let items = try await HunchAPI.shared.search(limit: 5)
            print("SUCCESS: Search returned \(items.count) items")
            for item in items {
                print("  - [\(item.object)] \(item.id): \(item.description)")
            }
        } catch {
            Self.printLastResponse(label: "search")
            if let decodingError = Self.extractDecodingError(from: error) {
                let desc = Self.describeDecodingError(decodingError)
                XCTFail("Decoding failed in search: \(desc)")
            } else {
                XCTFail("search failed: \(error)")
            }
        }
    }
}
