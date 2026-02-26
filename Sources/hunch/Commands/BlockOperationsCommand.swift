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
        abstract: "Append child blocks to a page or block (accepts --json, -j, or --blocks)"
    )

    @Argument(help: "The Notion block or page ID to append children to")
    var blockId: String

    @Option(name: [.short, .long, .customLong("blocks")], help: "JSON string of children blocks to append (reads from stdin if omitted)")
    var json: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        let childrenData: Data
        if let json = json, let data = json.data(using: .utf8) {
            childrenData = data
        } else {
            // Read from stdin
            var input = ""
            while let line = readLine() {
                input += line
            }
            guard let data = input.data(using: .utf8) else {
                throw ValidationError("Could not read JSON input")
            }
            childrenData = data
        }

        let blocks = try await HunchAPI.shared.appendBlockChildren(blockId: blockId, children: childrenData)
        try Hunch.output(list: blocks, format: format)
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
