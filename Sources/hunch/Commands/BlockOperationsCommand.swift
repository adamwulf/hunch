//
//  BlockOperationsCommand.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation
import ArgumentParser
import HunchKit

struct AppendBlocksCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "append-blocks",
        abstract: "Add child blocks to a page or block, at the end or after a sibling",
        discussion: """
            The blocks are a JSON array, like \
            [{"type":"paragraph","paragraph":{"rich_text":[{"text":{"content":"Hi"}}]}}], or an object \
            with a children array. To find ids, use hunch blocks <page-id> --format outline. The parent of \
            an indented block is the nearest line above it with less indent, and the parent of a block \
            with no indent is the page.
            """
    )

    @Argument(help: "The Notion block or page ID to append children to")
    var blockId: String

    @Option(name: .shortAndLong, help: "JSON string of children blocks to append (reads from stdin if omitted)")
    var blocks: String?

    @Option(name: .long, help: ArgumentHelp(
        "Insert the blocks after this block instead of at the end. It must be a direct child of <block-id>.",
        valueName: "sibling-id"
    ))
    var after: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        let childrenData = try readJSONInput(blocks, option: "--blocks")
        let body = try Self.requestBody(from: childrenData, after: after)
        let blocks = try await HunchAPI.shared.appendBlockChildren(blockId: blockId, children: body)
        try Hunch.output(list: blocks, format: format)
    }

    /// The request body for the append, with the sibling to insert after when there is one. hunch sends
    /// Notion-Version 2022-06-28, where that field is `after`. Version 2026-03-11 replaces it with a
    /// `position` object, so this changes when hunch moves to that version.
    static func requestBody(from childrenData: Data, after siblingId: String?) throws -> Data {
        let wrappedData = JSONChildrenWrapper.wrapIfNeeded(childrenData)
        // A single block object, or empty stdin, would otherwise reach Notion as a body with no children
        guard var body = try parseJSON(wrappedData) as? [String: Any], body["children"] is [Any] else {
            throw ValidationError("The blocks must be a JSON array of blocks or an object with a children array")
        }
        guard let siblingId = siblingId else {
            return wrappedData
        }
        guard body["after"] == nil, body["position"] == nil else {
            throw ValidationError("Give the position with --after or in the JSON, not both")
        }
        body["after"] = siblingId
        return try JSONSerialization.data(withJSONObject: body)
    }
}

struct UpdateBlockCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "update-block",
        abstract: "Update a block in place",
        discussion: """
            The JSON is sent as is to PATCH /v1/blocks/{id}. Its key must be the block's current type, \
            for example {"to_do":{"checked":true}}. A block's type cannot be changed. A new rich_text \
            replaces all of the block's text. To find the id and type of a block, use \
            hunch blocks <page-id> --format outline.
            """
    )

    @Argument(help: "The Notion block ID to update")
    var blockId: String

    @Option(name: .shortAndLong, help: "JSON object of the block fields to change (reads from stdin if omitted)")
    var block: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        let body = try Self.requestBody(from: readJSONInput(block, option: "--block"))
        let updatedBlock = try await HunchAPI.shared.updateBlock(blockId: blockId, body: body)
        try Hunch.output(list: [updatedBlock], format: format)
    }

    /// JSON that is not an object cannot be a block update, so this stops it before it is sent
    static func requestBody(from blockData: Data) throws -> Data {
        guard try parseJSON(blockData) is [String: Any] else {
            throw ValidationError("The block must be a JSON object, like {\"to_do\":{\"checked\":true}}")
        }
        return blockData
    }
}

struct DeleteBlockCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "delete-block",
        abstract: "Delete (archive) a block"
    )

    @Argument(help: "The Notion block ID to delete")
    var blockId: String

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        let block = try await HunchAPI.shared.deleteBlock(blockId: blockId)
        try Hunch.output(list: [block], format: format)
    }
}

/// The JSON given on the command line, or all of stdin when none was given. Stdin is read as is, so a
/// raw line break inside a JSON string is reported as invalid instead of being silently removed.
private func readJSONInput(_ json: String?, option: String) throws -> Data {
    if let json = json, let data = json.data(using: .utf8) {
        return data
    }
    // A terminal has no JSON to send, so reading it would wait for input that never comes
    guard isatty(STDIN_FILENO) == 0 else {
        throw ValidationError("Give the JSON with \(option) or on stdin")
    }
    return FileHandle.standardInput.readDataToEndOfFile()
}

/// The parsed JSON, or an error that says where its syntax is wrong
private func parseJSON(_ data: Data) throws -> Any {
    do {
        return try JSONSerialization.jsonObject(with: data)
    } catch {
        let reason = (error as NSError).userInfo[NSDebugDescriptionErrorKey] as? String ?? error.localizedDescription
        throw ValidationError("The input is not valid JSON: \(reason)")
    }
}
