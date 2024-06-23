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

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Format = .id

    enum Entity: String, ExpressibleByArgument {
        case database
        case page
    }

    enum Format: String, ExpressibleByArgument {
        case jsonl
        case id
    }

    func run() async {
        log(.debug, "notion_api", context: ["action": "fetch_db"])

        let limit = limit ?? .max
        var count = 0
        var cursor: String?
        var ret: [NotionItem] = []

        func fetchItems(with cursor: String?) async -> Result<(next: String?, items: [NotionItem]), NotionAPI.NotionAPIServiceError> {
            switch entity {
            case .database:
                switch await NotionAPI.shared.fetchDatabases(cursor: cursor) {
                case .success(let dbs): return .success(dbs.simpleList)
                case .failure(let error): return .failure(error)
                }
            case .page:
                switch await NotionAPI.shared.fetchPages(cursor: cursor) {
                case .success(let dbs): return .success(dbs.simpleList)
                case .failure(let error): return .failure(error)
                }
            }
        }

        var isFirstTry = true
        while isFirstTry || cursor != nil {
            isFirstTry = false
            let result = await fetchItems(with: cursor)
            switch result {
            case .success(let dbs):
                for db in dbs.items {
                    ret.append(db)
                    count += 1
                    guard count < limit else { break }
                }
                cursor = dbs.next
                guard count < limit else { break }
            case .failure(let error):
                print("error: \(error.localizedDescription)")
                return
            }
            guard count < limit else { break }
        }

        output(list: ret, format: format)
    }

    func output(list: [NotionItem], format: Format) {
        switch format {
        case .id:
            for item in list {
                print(item.id)
            }
        case .jsonl:
            do {
                let ret = try list.map({ ["object": $0.object, "id": $0.id ] }).compactMap({
                    let data = try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys)
                    return String(data: data, encoding: .utf8)
                })
                for line in ret {
                    print(line)
                }
            } catch {
                print("error: \(error.localizedDescription)")
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
