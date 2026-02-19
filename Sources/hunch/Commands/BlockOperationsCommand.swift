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
    var json: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
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
                    print("error: could not read JSON input")
                    return
                }
                childrenData = data
            }

            let blocks = try await HunchAPI.shared.appendBlockChildren(blockId: blockId, children: childrenData)
            Hunch.output(list: blocks, format: format)
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}

struct DeleteBlockCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "delete-blocks",
        abstract: "Delete (archive) a block"
    )

    @Argument(help: "The Notion block ID to delete")
    var blockId: String

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
            let block = try await HunchAPI.shared.deleteBlock(blockId: blockId)
            Hunch.output(list: [block], format: format)
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
