import XCTest
@testable import HunchKit
import OSLog

/// Integration tests that hit the real Notion API to diagnose decoding failures.
/// Skipped when no .env file with NOTION_KEY is found.
final class IntegrationTests: XCTestCase {

    /// Captured raw JSON responses keyed by API path
    static var capturedResponses: [(path: String, json: String)] = []

    /// Captured property decoding errors from the log handler
    static var propertyDecodingErrors: [(path: String, key: String, error: String)] = []

    override func setUp() async throws {
        try await super.setUp()

        guard let token = Self.loadNotionKey() else {
            throw XCTSkip("No .env file with NOTION_KEY found — skipping integration tests")
        }

        NotionAPI.shared.token = token
        Self.capturedResponses = []
        Self.propertyDecodingErrors = []

        // Install log handler to capture raw JSON responses and property decoding errors
        NotionAPI.logHandler = { level, message, context in
            if level == .debug && context == nil && (message.hasPrefix("{") || message.hasPrefix("[")) {
                // This is the raw JSON body log line
                let path = Self.capturedResponses.last?.path ?? "unknown"
                Self.capturedResponses.append((path: path, json: message))
            } else if level == .debug, let ctx = context, let path = ctx["path"] as? String {
                Self.capturedResponses.append((path: path, json: ""))
            } else if level == .error, let ctx = context,
                      let status = ctx["status"] as? String, status == "decoding_error",
                      let errorMsg = ctx["error"] as? String,
                      let key = ctx["key"] as? String {
                let path = ctx["path"] as? String ?? "unknown"
                Self.propertyDecodingErrors.append((path: path, key: key, error: errorMsg))
                print("  ⚠️ PROPERTY DECODING ERROR: type='\(key)' error='\(errorMsg)'")
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

    /// Recursively counts block types in a tree
    static func collectBlockTypes(from blocks: [Block]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for block in blocks {
            counts[block.type.rawValue, default: 0] += 1
            let childCounts = collectBlockTypes(from: block.children)
            for (key, value) in childCounts {
                counts[key, default: 0] += value
            }
        }
        return counts
    }

    // MARK: - Basic Integration Tests

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

    // MARK: - Comprehensive Page + Property Tests

    /// Test fetching pages from ALL databases and check every property type decodes
    func testAllDatabasePagesDecoding() async throws {
        print("\n=== testAllDatabasePagesDecoding ===")

        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 10)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        print("Found \(databases.count) databases")

        var allPropertyTypes: Set<String> = []
        var nullPropertyTypes: [String: Int] = [:]
        var totalPages = 0

        for db in databases {
            print("\n  Database: \(db.id) (\(db.description))")

            // Check database property schema
            print("    Schema properties:")
            for (name, prop) in db.properties.sorted(by: { $0.key < $1.key }) {
                print("      '\(name)': \(prop.kind)")
            }

            Self.propertyDecodingErrors = []

            do {
                let pages = try await HunchAPI.shared.fetchPages(databaseId: db.id, limit: 10)
                print("    Fetched \(pages.count) pages")
                totalPages += pages.count

                for page in pages {
                    for (name, prop) in page.properties {
                        allPropertyTypes.insert(prop.kind.rawValue)

                        if case .null(_, let type) = prop {
                            let key = "\(type.rawValue) (\(name))"
                            nullPropertyTypes[key, default: 0] += 1
                        }
                    }
                }

                // Report any property decoding errors
                if !Self.propertyDecodingErrors.isEmpty {
                    print("    ⚠️ Property decoding errors in this database:")
                    for err in Self.propertyDecodingErrors {
                        print("      type='\(err.key)' error='\(err.error)'")
                    }
                }
            } catch {
                if let decodingError = Self.extractDecodingError(from: error) {
                    let desc = Self.describeDecodingError(decodingError)
                    XCTFail("Decoding failed for database \(db.id): \(desc)")
                } else {
                    XCTFail("Failed to fetch pages from \(db.id): \(error)")
                }
            }
        }

        print("\n  Summary:")
        print("    Total pages decoded: \(totalPages)")
        print("    Property types seen: \(allPropertyTypes.sorted().joined(separator: ", "))")
        if !nullPropertyTypes.isEmpty {
            print("    Null property types (decoded but value was null):")
            for (key, count) in nullPropertyTypes.sorted(by: { $0.key < $1.key }) {
                print("      \(key): \(count) occurrences")
            }
        }
        XCTAssertGreaterThan(totalPages, 0, "Expected at least some pages across all databases")
    }

    /// Test encoding page properties back to JSON (simulates export caching)
    func testPagePropertyEncoding() async throws {
        print("\n=== testPagePropertyEncoding ===")

        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 3)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var encodeErrors: [(page: String, error: String)] = []

        for db in databases {
            do {
                let pages = try await HunchAPI.shared.fetchPages(databaseId: db.id, limit: 5)
                for page in pages {
                    do {
                        // This is what the export command does - encode properties to JSON
                        let data = try encoder.encode(page.properties)
                        // Verify it's valid JSON
                        _ = try JSONSerialization.jsonObject(with: data)
                        print("  ✓ Page '\(page.description)' properties encoded OK (\(data.count) bytes)")
                    } catch {
                        let msg = "Page \(page.id) (\(page.description)): \(error)"
                        encodeErrors.append((page: page.id, error: msg))
                        print("  ✗ \(msg)")
                    }
                }
            } catch {
                print("  ⚠️ Skipping database \(db.id): \(error)")
            }
        }

        if !encodeErrors.isEmpty {
            XCTFail("\(encodeErrors.count) page(s) failed property encoding:\n" + encodeErrors.map { $0.error }.joined(separator: "\n"))
        }
    }

    // MARK: - Comprehensive Block Tests

    /// Test fetching and decoding blocks from multiple pages across databases
    func testBlockDecodingAcrossPages() async throws {
        print("\n=== testBlockDecodingAcrossPages ===")

        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 3)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        var allBlockTypes: [String: Int] = [:]
        var blockErrors: [(page: String, error: String)] = []
        var pagesWithBlocks = 0

        for db in databases.prefix(2) {
            let pages: [Page]
            do {
                pages = try await HunchAPI.shared.fetchPages(databaseId: db.id, limit: 5)
            } catch {
                print("  ⚠️ Skipping database \(db.id): \(error)")
                continue
            }

            for page in pages {
                do {
                    let blocks = try await HunchAPI.shared.fetchBlocks(in: page.id)
                    if !blocks.isEmpty {
                        pagesWithBlocks += 1
                        let typeCounts = Self.collectBlockTypes(from: blocks)
                        for (blockType, count) in typeCounts {
                            allBlockTypes[blockType, default: 0] += count
                        }
                        let typeStr = typeCounts.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value)" }.joined(separator: ", ")
                        print("  ✓ Page '\(page.description)' — \(blocks.count) top-level blocks [\(typeStr)]")
                    } else {
                        print("  ✓ Page '\(page.description)' — 0 blocks")
                    }
                } catch {
                    let decodingDesc: String
                    if let decodingError = Self.extractDecodingError(from: error) {
                        decodingDesc = Self.describeDecodingError(decodingError)
                    } else {
                        decodingDesc = error.localizedDescription
                    }
                    let msg = "Page \(page.id) (\(page.description)): \(decodingDesc)"
                    blockErrors.append((page: page.id, error: msg))
                    print("  ✗ \(msg)")
                }
            }
        }

        print("\n  Summary:")
        print("    Pages with blocks: \(pagesWithBlocks)")
        print("    Block types seen: \(allBlockTypes.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value)" }.joined(separator: ", "))")

        if !blockErrors.isEmpty {
            XCTFail("\(blockErrors.count) page(s) failed block decoding:\n" + blockErrors.map { $0.error }.joined(separator: "\n"))
        }
    }

    /// Test block encode/decode roundtrip (simulates the export command's JSON caching)
    func testBlockEncodingRoundtrip() async throws {
        print("\n=== testBlockEncodingRoundtrip ===")

        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 2)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var roundtripErrors: [(page: String, error: String)] = []

        for db in databases.prefix(2) {
            let pages: [Page]
            do {
                pages = try await HunchAPI.shared.fetchPages(databaseId: db.id, limit: 3)
            } catch {
                print("  ⚠️ Skipping database \(db.id): \(error)")
                continue
            }

            for page in pages {
                do {
                    let blocks = try await HunchAPI.shared.fetchBlocks(in: page.id)
                    guard !blocks.isEmpty else { continue }

                    // Encode to JSON (what ExportCommand does for caching)
                    let jsonData = try encoder.encode(blocks)
                    print("  ✓ Encoded \(blocks.count) blocks (\(jsonData.count) bytes) for '\(page.description)'")

                    // Decode back (what ExportCommand does when loading from cache)
                    let decoded = try JSONDecoder().decode([Block].self, from: jsonData)
                    XCTAssertEqual(decoded.count, blocks.count, "Block count mismatch after roundtrip for page \(page.id)")

                    // Verify types match
                    for (original, roundtripped) in zip(blocks, decoded) {
                        XCTAssertEqual(original.type, roundtripped.type,
                                       "Block type mismatch: \(original.type.rawValue) vs \(roundtripped.type.rawValue) for block \(original.id)")
                    }
                    print("    ✓ Roundtrip verified: \(decoded.count) blocks match")
                } catch {
                    let msg: String
                    if let decodingError = Self.extractDecodingError(from: error) {
                        msg = "Page \(page.id): \(Self.describeDecodingError(decodingError))"
                    } else if let decodingError = error as? DecodingError {
                        msg = "Page \(page.id): \(Self.describeDecodingError(decodingError))"
                    } else {
                        msg = "Page \(page.id): \(error)"
                    }
                    roundtripErrors.append((page: page.id, error: msg))
                    print("  ✗ \(msg)")
                }
            }
        }

        if !roundtripErrors.isEmpty {
            XCTFail("\(roundtripErrors.count) page(s) failed block roundtrip:\n" + roundtripErrors.map { $0.error }.joined(separator: "\n"))
        }
    }

    // MARK: - Retrieve Page Tests

    /// Test retrieving individual pages (GET /pages/{id}) for multiple pages
    func testRetrieveMultiplePages() async throws {
        print("\n=== testRetrieveMultiplePages ===")

        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 2)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        var retrieveErrors: [(page: String, error: String)] = []

        for db in databases {
            let pages: [Page]
            do {
                pages = try await HunchAPI.shared.fetchPages(databaseId: db.id, limit: 5)
            } catch {
                print("  ⚠️ Skipping database \(db.id): \(error)")
                continue
            }

            for page in pages {
                Self.propertyDecodingErrors = []
                do {
                    let retrieved = try await HunchAPI.shared.retrievePage(pageId: page.id)
                    let propSummary = retrieved.properties.sorted(by: { $0.key < $1.key }).map { name, prop in
                        "\(name):\(prop.kind.rawValue)"
                    }.joined(separator: ", ")
                    print("  ✓ Retrieved '\(retrieved.description)' — [\(propSummary)]")

                    if !Self.propertyDecodingErrors.isEmpty {
                        print("    ⚠️ Property decoding fell back to .null for:")
                        for err in Self.propertyDecodingErrors {
                            print("      type='\(err.key)' error='\(err.error)'")
                        }
                    }
                } catch {
                    let msg: String
                    if let decodingError = Self.extractDecodingError(from: error) {
                        msg = "Page \(page.id): \(Self.describeDecodingError(decodingError))"
                    } else {
                        msg = "Page \(page.id): \(error)"
                    }
                    retrieveErrors.append((page: page.id, error: msg))
                    print("  ✗ \(msg)")
                }
            }
        }

        if !retrieveErrors.isEmpty {
            XCTFail("\(retrieveErrors.count) page(s) failed retrieval:\n" + retrieveErrors.map { $0.error }.joined(separator: "\n"))
        }
    }

    // MARK: - Full Export Simulation

    /// Simulates the full export flow: fetch pages, fetch blocks, encode everything
    func testFullExportSimulation() async throws {
        print("\n=== testFullExportSimulation ===")

        let databases: [Database]
        do {
            databases = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 2)
            guard !databases.isEmpty else {
                throw XCTSkip("No databases found")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            XCTFail("Failed to fetch databases: \(error)")
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var errors: [String] = []

        for db in databases.prefix(1) {
            print("\n  Simulating export for database: \(db.description)")

            let pages: [Page]
            do {
                pages = try await HunchAPI.shared.fetchPages(databaseId: db.id, limit: 10)
                print("  Fetched \(pages.count) pages")
            } catch {
                errors.append("fetchPages(\(db.id)): \(error)")
                continue
            }

            for page in pages {
                Self.propertyDecodingErrors = []
                print("\n    Page: \(page.description)")

                // Step 1: Encode properties (like ExportCommand does)
                do {
                    let propData = try encoder.encode(page.properties)
                    print("      ✓ Properties encoded (\(propData.count) bytes)")
                } catch {
                    errors.append("encodeProperties(\(page.id)): \(error)")
                    print("      ✗ Properties encoding failed: \(error)")
                }

                // Step 2: Fetch blocks
                let blocks: [Block]
                do {
                    blocks = try await HunchAPI.shared.fetchBlocks(in: page.id)
                    print("      ✓ Fetched \(blocks.count) blocks")
                } catch {
                    let decodingDesc: String
                    if let decodingError = Self.extractDecodingError(from: error) {
                        decodingDesc = Self.describeDecodingError(decodingError)
                    } else {
                        decodingDesc = "\(error)"
                    }
                    errors.append("fetchBlocks(\(page.id)): \(decodingDesc)")
                    print("      ✗ Blocks fetch failed: \(decodingDesc)")
                    continue
                }

                // Step 3: Encode blocks to JSON (caching)
                do {
                    let blockData = try encoder.encode(blocks)
                    print("      ✓ Blocks encoded (\(blockData.count) bytes)")

                    // Step 4: Decode blocks back (reading from cache)
                    let decoded = try JSONDecoder().decode([Block].self, from: blockData)
                    print("      ✓ Blocks roundtrip OK (\(decoded.count) blocks)")
                } catch {
                    let decodingDesc: String
                    if let decodingError = error as? DecodingError {
                        decodingDesc = Self.describeDecodingError(decodingError)
                    } else {
                        decodingDesc = "\(error)"
                    }
                    errors.append("blockRoundtrip(\(page.id)): \(decodingDesc)")
                    print("      ✗ Block roundtrip failed: \(decodingDesc)")
                }

                // Step 5: Check for property decoding issues
                if !Self.propertyDecodingErrors.isEmpty {
                    print("      ⚠️ \(Self.propertyDecodingErrors.count) property decoding error(s):")
                    for err in Self.propertyDecodingErrors {
                        print("        type='\(err.key)' error='\(err.error)'")
                    }
                }
            }
        }

        print("\n  === Export Simulation Complete ===")
        if errors.isEmpty {
            print("  All operations succeeded!")
        } else {
            print("  \(errors.count) error(s):")
            for err in errors {
                print("    - \(err)")
            }
            XCTFail("\(errors.count) error(s) during export simulation:\n" + errors.joined(separator: "\n"))
        }
    }

    // MARK: - Real Export to /tmp

    /// Searches for the "Example" database and runs a real export to /tmp,
    /// replicating the ExportCommand flow: properties.json, content.json, content.md, .webloc
    func testExportExampleDatabaseToTmp() async throws {
        print("\n=== testExportExampleDatabaseToTmp ===")

        // Search for the "Example" database by name
        let searchResults = try await HunchAPI.shared.search(
            query: "Example",
            filter: SearchFilter(value: "database"),
            limit: 20
        )

        let exampleDB: Database? = searchResults.compactMap { item -> Database? in
            guard let db = item as? Database else { return nil }
            let title = db.title.map { $0.plainText }.joined()
            print("  Found database: '\(title)' (\(db.id))")
            if title.lowercased().contains("example") {
                return db
            }
            return nil
        }.first

        guard let db = exampleDB else {
            // Fallback: try fetching all databases with a higher limit
            print("  Search didn't find 'Example'. Trying fetchDatabases with higher limit...")
            let allDBs = try await HunchAPI.shared.fetchDatabases(parentId: nil, limit: 50)
            let found = allDBs.first { db in
                let title = db.title.map { $0.plainText }.joined()
                print("  Database: '\(title)' (\(db.id))")
                return title.lowercased().contains("example")
            }
            guard let found = found else {
                throw XCTSkip("No 'Example' database found in this Notion workspace")
            }
            try await runExportToTmp(database: found)
            return
        }

        try await runExportToTmp(database: db)
    }

    /// Runs the full export flow for a database, writing files to /tmp/notion_export_test/
    private func runExportToTmp(database db: Database) async throws {
        let fm = FileManager.default
        let outputDir = "/tmp/notion_export_test"

        // Clean up any previous test output
        if fm.fileExists(atPath: outputDir) {
            try fm.removeItem(atPath: outputDir)
        }
        try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let dbTitle = db.title.map { $0.plainText }.joined()
        print("\n  Exporting database: '\(dbTitle)' (\(db.id))")
        print("  Output directory: \(outputDir)")

        // Fetch all pages from the database
        let pages = try await HunchAPI.shared.fetchPages(databaseId: db.id)
        print("  Fetched \(pages.count) pages")
        XCTAssertGreaterThan(pages.count, 0, "Expected at least one page in the Example database")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = .init(secondsFromGMT: 0)
        dateFormatter.formatOptions = [.withInternetDateTime]

        var errors: [String] = []
        var allPropertyTypes: Set<String> = []
        var allBlockTypes: [String: Int] = [:]

        for page in pages {
            Self.propertyDecodingErrors = []
            let pageTitle = page.title.map { $0.plainText }.joined().replacingOccurrences(of: "\n", with: " ")
            print("\n    Page: '\(pageTitle)' (\(page.id))")

            // Track property types
            for (name, prop) in page.properties {
                allPropertyTypes.insert(prop.kind.rawValue)
                if case .null(_, let type) = prop {
                    print("      null property: '\(name)' (type: \(type.rawValue))")
                }
            }

            // Create page directory structure (matches ExportCommand)
            let pageDir = (outputDir as NSString).appendingPathComponent(page.id + ".localized")
            let localizedDir = (pageDir as NSString).appendingPathComponent(".localized")
            try fm.createDirectory(atPath: pageDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: localizedDir, withIntermediateDirectories: true)

            // Step 1: Write Base.strings
            let escapedName = pageTitle
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\t", with: "\\t")
            let semi = "\u{003B}"
            let stringsContent = "\"\(page.id)\" = \"\(escapedName)\"\(semi)"
            let stringsPath = (localizedDir as NSString).appendingPathComponent("Base.strings")
            try stringsContent.write(toFile: stringsPath, atomically: true, encoding: .utf8)
            print("      ✓ Base.strings written")

            // Step 2: Write properties.json
            do {
                let propertiesData = try encoder.encode(page.properties)
                let propertiesPath = (pageDir as NSString).appendingPathComponent("properties.json")
                try propertiesData.write(to: URL(fileURLWithPath: propertiesPath))
                print("      ✓ properties.json written (\(propertiesData.count) bytes)")
            } catch {
                errors.append("properties.json(\(page.id)): \(error)")
                print("      ✗ properties.json failed: \(error)")
            }

            // Step 3: Fetch blocks
            let blocks: [Block]
            do {
                blocks = try await HunchAPI.shared.fetchBlocks(in: page.id)
                print("      ✓ Fetched \(blocks.count) blocks")

                // Track block types
                let typeCounts = Self.collectBlockTypes(from: blocks)
                for (blockType, count) in typeCounts {
                    allBlockTypes[blockType, default: 0] += count
                }
                if !typeCounts.isEmpty {
                    let typeStr = typeCounts.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value)" }.joined(separator: ", ")
                    print("        Block types: [\(typeStr)]")
                }
            } catch {
                let desc: String
                if let decodingError = Self.extractDecodingError(from: error) {
                    desc = Self.describeDecodingError(decodingError)
                } else {
                    desc = "\(error)"
                }
                errors.append("fetchBlocks(\(page.id)): \(desc)")
                print("      ✗ fetchBlocks failed: \(desc)")
                continue
            }

            // Step 4: Write content.json (block cache)
            do {
                let blockData = try encoder.encode(blocks)
                let contentJsonPath = (pageDir as NSString).appendingPathComponent("content.json")
                try blockData.write(to: URL(fileURLWithPath: contentJsonPath))
                print("      ✓ content.json written (\(blockData.count) bytes)")

                // Verify roundtrip
                let decoded = try JSONDecoder().decode([Block].self, from: blockData)
                XCTAssertEqual(decoded.count, blocks.count,
                               "Block count mismatch after roundtrip for page \(page.id)")
                print("      ✓ content.json roundtrip verified (\(decoded.count) blocks)")
            } catch {
                let desc: String
                if let decodingError = error as? DecodingError {
                    desc = Self.describeDecodingError(decodingError)
                } else {
                    desc = "\(error)"
                }
                errors.append("content.json(\(page.id)): \(desc)")
                print("      ✗ content.json failed: \(desc)")
            }

            // Step 5: Render markdown (like ExportCommand does)
            do {
                let renderer = MarkdownRenderer(
                    level: 0,
                    ignoreColor: false,
                    ignoreUnderline: false,
                    downloadedAssets: [:])

                // Build frontmatter (same as ExportCommand)
                let selectProperties = page.properties
                    .sorted(by: { $0.key < $1.key })
                    .compactMap { (name: String, prop: Property) -> (String, [String])? in
                        switch prop {
                        case .multiSelect(_, let values):
                            return (name, values.map { $0.name })
                        case .select(_, let value):
                            return (name, [value.name])
                        case .url(_, let value):
                            return (name, [value])
                        case .formula(_, let value):
                            return (name, [value.type.stringValue ?? ""])
                        case .checkbox(_, let value):
                            return (name, [value ? "Yes" : "No"])
                        case .number(_, let value):
                            return (name, [String(value)])
                        case .date(_, let value):
                            let formatter = ISO8601DateFormatter()
                            let start = formatter.string(from: value.start)
                            let end = value.end.map { formatter.string(from: $0) }
                            return (name, [start] + (end.map { [" - ", $0] } ?? []))
                        case .email(_, let value):
                            return (name, [value])
                        case .phoneNumber(_, let value):
                            return (name, [value])
                        case .relation(_, let values):
                            return (name, values.map { $0.id })
                        case .rollup(_, let value):
                            return (name, [value.value])
                        case .people(_, let users):
                            return (name, users.compactMap { $0.name })
                        case .file(_, let files), .files(_, let files):
                            return (name, files.map { $0.url })
                        case .createdBy(_, let user):
                            return (name, [user.name].compactMap({ $0 }))
                        case .lastEditedBy(_, let user):
                            return (name, [user.name].compactMap({ $0 }))
                        default:
                            return nil
                        }
                    }

                let emoji = page.icon?.emoji.map({ $0 + " " }) ?? ""
                let titleHeader = """
                    ---
                    title: "\(emoji)\(try renderer.render(page.title))"
                    created: \(dateFormatter.string(from: page.created))
                    lastEdited: \(dateFormatter.string(from: page.lastEdited))
                    archived: \(page.archived)
                    id: \(page.id)
                    \(selectProperties.map { name, values in
                        "\(name.lowercased()): \(values.joined(separator: ", "))"
                    }.joined(separator: "\n"))
                    ---


                    """

                let markdown = titleHeader + (try renderer.render([page] + blocks))
                let mdPath = (pageDir as NSString).appendingPathComponent("content.md")
                try markdown.write(toFile: mdPath, atomically: true, encoding: .utf8)
                print("      ✓ content.md written (\(markdown.count) chars)")
            } catch {
                errors.append("markdown(\(page.id)): \(error)")
                print("      ✗ Markdown rendering failed: \(error)")
            }

            // Step 6: Write .webloc file
            do {
                let weblocContent = """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
                    <plist version="1.0">
                    <dict>
                        <key>URL</key>
                        <string>https://www.notion.so/\(page.id.replacingOccurrences(of: "-", with: ""))</string>
                    </dict>
                    </plist>
                    """
                var filename = pageTitle
                if filename.isEmpty { filename = "Link" }
                // Sanitize filename: replace path separators and other unsafe characters
                filename = filename
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: ":", with: "_")
                let maxLength = 255 - ".webloc".count
                if filename.count > maxLength {
                    filename = String(filename.prefix(maxLength))
                }
                let weblocPath = (pageDir as NSString).appendingPathComponent(filename + ".webloc")
                try weblocContent.write(toFile: weblocPath, atomically: true, encoding: .utf8)
                print("      ✓ .webloc written")
            } catch {
                errors.append("webloc(\(page.id)): \(error)")
                print("      ✗ .webloc failed: \(error)")
            }

            // Report property decoding issues
            if !Self.propertyDecodingErrors.isEmpty {
                print("      ⚠️ \(Self.propertyDecodingErrors.count) property decoding error(s):")
                for err in Self.propertyDecodingErrors {
                    print("        type='\(err.key)' error='\(err.error)'")
                }
            }
        }

        // Print summary
        print("\n  === Export Complete ===")
        print("  Output: \(outputDir)")
        print("  Pages exported: \(pages.count)")
        print("  Property types: \(allPropertyTypes.sorted().joined(separator: ", "))")
        print("  Block types: \(allBlockTypes.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value)" }.joined(separator: ", "))")

        // Verify output files exist
        let exportedDirs = try fm.contentsOfDirectory(atPath: outputDir)
            .filter { $0.hasSuffix(".localized") }
        print("  Exported directories: \(exportedDirs.count)")

        for dir in exportedDirs {
            let dirPath = (outputDir as NSString).appendingPathComponent(dir)
            let files = try fm.contentsOfDirectory(atPath: dirPath)
            print("    \(dir): \(files.joined(separator: ", "))")

            // Verify key files exist
            XCTAssertTrue(files.contains("properties.json"), "Missing properties.json in \(dir)")
            XCTAssertTrue(files.contains("content.json"), "Missing content.json in \(dir)")
            XCTAssertTrue(files.contains("content.md"), "Missing content.md in \(dir)")
        }

        if errors.isEmpty {
            print("\n  All operations succeeded!")
        } else {
            print("\n  \(errors.count) error(s):")
            for err in errors {
                print("    - \(err)")
            }
            XCTFail("\(errors.count) error(s) during export:\n" + errors.joined(separator: "\n"))
        }
    }
}
