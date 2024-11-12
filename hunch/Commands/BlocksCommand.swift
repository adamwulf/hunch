//
//  Content.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox

struct BlocksCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "blocks",
        abstract: "Fetch block content from Notion"
    )

    @Argument(help: "The Notion id of the object") var pageId: String

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    @Flag(name: .long, help: "Ignore colors in markdown formatting")
    var ignoreColor: Bool = false

    @Flag(name: .long, help: "Ignore underlined formatting in markdown")
    var ignoreUnderline: Bool = false

    func run() async {
        let rootBlocks = await HunchAPI.shared.fetchBlocks(in: pageId)
        Hunch.output(list: rootBlocks, format: format, ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline)
    }
}
