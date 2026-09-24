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
        abstract: "Append child blocks to a page or block"
    )

    @Argument(help: "The Notion block or page ID to append children to")
    var blockId: String

    @Option(name: .shortAndLong, help: "JSON string of children blocks to append (reads from stdin if omitted)")
    var blocks: String?

    @Option(name: .long, help: "Insert the blocks after this child block instead of at the end")
    var after: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        let childrenData = try readJSONInput(blocks)
        let body = try Self.requestBody(from: childrenData, after: after)
        let blocks = try await HunchAPI.shared.appendBlockChildren(blockId: blockId, children: body)
        try Hunch.output(list: blocks, format: format)
    }

    /// The request body for the append, with the sibling to insert after when there is one. hunch sends
    /// Notion-Version 2022-06-28, where that field is `after`. Version 2026-03-11 replaces it with a
    /// `position` object, so this is the one place to change when hunch moves to that version.
    static func requestBody(from childrenData: Data, after siblingId: String?) throws -> Data {
        let wrappedData = JSONChildrenWrapper.wrapIfNeeded(childrenData)
        guard let siblingId = siblingId else {
            return wrappedData
        }
        guard var body = (try? JSONSerialization.jsonObject(with: wrappedData)) as? [String: Any] else {
            throw ValidationError("--after needs the blocks to be a JSON array or an object with a children array")
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
            replaces all of the block's text.
            """
    )

    @Argument(help: "The Notion block ID to update")
    var blockId: String

    @Option(name: .shortAndLong, help: "JSON object of the block fields to change (reads from stdin if omitted)")
    var block: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        let body = try Self.requestBody(from: readJSONInput(block))
        let updatedBlock = try await HunchAPI.shared.updateBlock(blockId: blockId, body: body)
        try Hunch.output(list: [updatedBlock], format: format)
    }

    /// Notion answers malformed JSON with a bare 400, so this says what is wrong before sending it
    static func requestBody(from blockData: Data) throws -> Data {
        guard (try? JSONSerialization.jsonObject(with: blockData)) is [String: Any] else {
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

/// The JSON given on the command line, or all of stdin when none was given
private func readJSONInput(_ json: String?) throws -> Data {
    if let json = json, let data = json.data(using: .utf8) {
        return data
    }
    var input = ""
    while let line = readLine() {
        input += line
    }
    guard let data = input.data(using: .utf8) else {
        throw ValidationError("Could not read JSON input")
    }
    return data
}
