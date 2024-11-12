//
//  Page.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox

struct PageCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "page",
        abstract: "Fetch pages from Notion"
    )

    @Option(name: .shortAndLong, help: "The Notion id of the object") var database: String?

    @Option(name: .shortAndLong, help: "The maxiumum number of results to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        let limit = limit ?? .max
        var count = 0
        var cursor: String?
        var ret: [NotionItem] = []

        var isFirstTry = true
        while isFirstTry || cursor != nil {
            isFirstTry = false
            let result = await NotionAPI.shared.fetchPages(cursor: cursor, databaseId: database)
            switch result {
            case .success(let pages):
                for page in pages.results {
                    ret.append(page)
                    count += 1
                    guard count < limit else { break }
                }
                cursor = pages.nextCursor
                guard count < limit else { break }
            case .failure(let error):
                fatalError("error: \(error.localizedDescription)")
            }
            guard count < limit else { break }
        }

        Hunch.output(list: ret, format: format)
    }
}
