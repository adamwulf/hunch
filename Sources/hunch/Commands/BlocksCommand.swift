//
//  BlocksCommand.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox
import HunchKit

struct BlocksCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "blocks",
        abstract: "Fetch block content from Notion",
        discussion: """
            To find a block to edit, use --format outline. It prints one line per block as \
            <id> <type> <text>, with two spaces of indent for each level of nesting. Give these ids to \
            update-block, delete-block, and append-blocks --after. These marks are not part of a block's \
            text: [ ] or [x] before a to_do, \\n for a line break, \\\\ for a backslash, and \
            "synced from <id>" on a copy of a synced block, whose children belong to that original.
            """
    )

    @Argument(help: "The Notion page or block ID to fetch blocks from") var pageId: String

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    @Flag(name: .long, help: "Ignore colors in markdown formatting")
    var ignoreColor: Bool = false

    @Flag(name: .long, help: "Ignore underlined formatting in markdown")
    var ignoreUnderline: Bool = false

    func run() async throws {
        let rootBlocks = try await HunchAPI.shared.fetchBlocks(in: pageId)
        try Hunch.output(list: rootBlocks, format: format, ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline)
    }
}
