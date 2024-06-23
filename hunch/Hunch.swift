//
//  main.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//

import Foundation
import ArgumentParser
import SwiftToolbox

@main
struct Hunch: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "hunch",
        version: "Hunch",
        subcommands: [Fetch.self]
    )

    init() {
        guard let key = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            fatalError("NOTION_KEY must be defined in environment")
        }
        Logging.configure()
        NotionAPI.shared.token = key
    }
}

struct Fetch: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Fetch pages or databases from Notion"
    )

    @Argument var entity: Entity

    @Argument var entityId: String?

    @Option(name: .shortAndLong, help: "The maxiumum number of results to return")
    var limit: Int?

    enum Entity: String, ExpressibleByArgument {
        case database
        case page
    }

    func run() async {
        log(.debug, "notion_api", context: ["action": "fetch_db"])

        let limit = limit ?? .max
        var count = 0
        var cursor: String?
        var hasResults = true

        switch entity {
        case .database:
            while hasResults {
                let result = await NotionAPI.shared.fetchDatabases(cursor: cursor)
                switch result {
                case .success(let dbs):
                    for db in dbs.results {
                        print("\(db.id)")
                        count += 1
                        guard count < limit else { return }
                    }
                    hasResults = dbs.hasMore
                    cursor = dbs.nextCursor
                case .failure(let error):
                    print("error: \(error.localizedDescription)")
                }
            }
        case .page:
            while hasResults {
                let result = await NotionAPI.shared.fetchPages(cursor: cursor)
                switch result {
                case .success(let pages):
                    for page in pages.results {
                        print("\(page.id)")
                        count += 1
                        guard count < limit else { return }
                    }
                    hasResults = pages.hasMore
                    cursor = pages.nextCursor
                case .failure(let error):
                    print("error: \(error.localizedDescription)")
                    hasResults = false
                }
            }
        }
    }
}

//
// NotionAPI.shared.fetchDatabases { result in
//    switch result {
//    case .success(let dbs):
//        for db in dbs.results {
//            group.enter()
//            log(.debug, "notion_api", context: ["action": "fetch_entries", "db": db.plainTextTitle])
//            NotionAPI.shared.fetchDatabaseEntries(in: db) { result in
//                switch result {
//                case .success(let pages):
//                    for page in pages.results {
//                        print(page.plainTextTitle)
//                    }
//                    if let firstPage = pages.results.first {
//                        group.enter()
//                        NotionAPI.shared.fetchPageContent(in: firstPage) { result in
//                            switch result {
//                            case .success(let blocks):
//                                print(blocks)
//                            case .failure(let error):
//                                print(error)
//                            }
//                            group.leave()
//                        }
//                    }
//                case .failure(let error):
//                    print(error)
//                }
//                group.leave()
//            }
//            print(db.plainTextTitle)
//        }
//    case .failure(let error):
//        print(error)
//    }
//    group.leave()
// }
////        group.enter()
////        NotionAPI.shared.fetchPages { result in
////            switch result {
////            case .success(let pages):
////                for page in pages.results {
////                    print(page.plainTextTitle)
////                }
////            case .failure(let error):
////                print(error)
////            }
////            group.leave()
////        }
// group.wait()
