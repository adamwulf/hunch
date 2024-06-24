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

    func run() async {
        var count = 0
        var cursor: String?
        var ret: [NotionItem] = []

        var isFirstTry = true
        while isFirstTry || cursor != nil {
            isFirstTry = false
            let result = await NotionAPI.shared.fetchPageContent(in: pageId)
            switch result {
            case .success(let blocks):
                for block in blocks.results {
                    ret.append(block)
                    count += 1
                }
                cursor = blocks.nextCursor
            case .failure(let error):
                fatalError("error: \(error.localizedDescription)")
            }
        }

        Hunch.output(list: ret, format: format)
    }
}
