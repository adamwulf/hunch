//
//  Database.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox

struct DatabaseCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "database",
        abstract: "Fetch databases from Notion"
    )

    @Argument(help: "The Notion id of the object") var entityId: String?

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
            let result = await NotionAPI.shared.fetchDatabases(cursor: cursor)
            switch result {
            case .success(let dbs):
                for db in dbs.results {
                    ret.append(db)
                    count += 1
                    guard count < limit else { break }
                }
                cursor = dbs.nextCursor
                guard count < limit else { break }
            case .failure(let error):
                fatalError("error: \(error.localizedDescription)")
            }
            guard count < limit else { break }
        }

        Hunch.output(list: ret, format: format)
    }
}
