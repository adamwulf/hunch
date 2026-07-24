import XCTest
@testable import HunchKit

/// Verifies that decode failures surface enough context to diagnose the
/// offending page/block and block type, rather than the opaque
/// "isn't in the correct format" message. See the undocumented `heading_4`
/// export failure that motivated this diagnostic detail.
final class DecodeErrorTests: XCTestCase {
    let decoder = JSONDecoder()

    /// A `BlockList` response whose single block carries an undocumented
    /// `type` value, reproducing the real-world decode failure.
    private func blockListWithUnknownType(_ type: String) -> Data {
        return """
        {
            "results": [
                {
                    "object": "block",
                    "id": "block-1",
                    "parent": {"type": "page_id", "page_id": "page-abc"},
                    "type": "\(type)",
                    "created_time": "2024-01-01",
                    "created_by": {"object": "user", "id": "user-1"},
                    "last_edited_time": "2024-01-01",
                    "last_edited_by": {"object": "user", "id": "user-1"},
                    "archived": false,
                    "in_trash": false,
                    "has_children": false,
                    "\(type)": {"rich_text": [], "color": "default"}
                }
            ],
            "next_cursor": null,
            "has_more": false
        }
        """.data(using: .utf8)!
    }

    func testDecodingDetailNamesOffendingBlockTypeAndPath() throws {
        do {
            _ = try decoder.decode(BlockList.self, from: blockListWithUnknownType("heading_99"))
            XCTFail("Expected decoding of an unknown block type to fail")
        } catch {
            let detail = NotionAPI.NotionAPIServiceError.decodingDetail(error)
            // Names the offending value ...
            XCTAssertTrue(detail.contains("heading_99"),
                          "Expected the offending block type in the detail, got: \(detail)")
            // ... and the coding path to the failing field.
            XCTAssertTrue(detail.contains("type"),
                          "Expected the coding path to the 'type' field, got: \(detail)")
            XCTAssertTrue(detail.contains("results"),
                          "Expected the coding path to include 'results', got: \(detail)")
        }
    }

    func testDecodeErrorMessageIncludesRequestContext() throws {
        do {
            _ = try decoder.decode(BlockList.self, from: blockListWithUnknownType("heading_99"))
            XCTFail("Expected decoding of an unknown block type to fail")
        } catch {
            let context = "/v1/blocks/3a7f32f4-36c1-81cd-a74d-f8da5db159b0/children"
            let serviceError = NotionAPI.NotionAPIServiceError.decodeError(error, context: context)
            let message = serviceError.localizedDescription
            // The page/block id is discoverable from the request path ...
            XCTAssertTrue(message.contains(context),
                          "Expected the request context in the message, got: \(message)")
            // ... alongside the offending block type.
            XCTAssertTrue(message.contains("heading_99"),
                          "Expected the offending block type in the message, got: \(message)")
            XCTAssertTrue(message.hasPrefix("decode error"),
                          "Expected a 'decode error' prefix, got: \(message)")
        }
    }

    func testDecodingDetailFallsBackForNonDecodingErrors() {
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "kaboom" }
        }
        let detail = NotionAPI.NotionAPIServiceError.decodingDetail(Boom())
        XCTAssertEqual(detail, "kaboom")
    }
}
