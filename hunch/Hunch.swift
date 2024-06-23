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
struct Hunch: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "hunch",
        version: "Hunch",
        subcommands: [Fetch.self]
    )

    init() {
        NotionAPI.logHandler = { (_ logLevel: NotionAPI.LogLevel, _ message: String, _ context: [String: Any]?) in
            print("\(logLevel.stringValue) \(message) \(String.logfmt(context ?? [:]))")
        }

        guard let key = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            fatalError("NOTION_KEY must be defined in environment")
        }
        NotionAPI.shared.token = key
    }
}

func log(_ logLevel: NotionAPI.LogLevel, _ message: String, context: [String: Any]? = nil) {
    print("\(logLevel.stringValue) \(message) \(String.logfmt(context ?? [:]))")
}

struct Fetch: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Fetch pages or databases from Notion"
    )

    @Argument var entity: Entity

    @Argument var entityId: String?

    enum Entity: String, ExpressibleByArgument {
        case database
        case page
    }

    func run() {
        log(.debug, "notion_api", context: ["action": "fetch_db"])

        let group = DispatchGroup() // initialize
        group.enter()

        switch entity {
        case .database:
            NotionAPI.shared.fetchDatabases { result in
                switch result {
                case .success(let dbs):
                    print("\(dbs.object)");
                    for db in dbs.results {
                        print("\(db.id)")
                    }
                case .failure(let error):
                    print("\(error.localizedDescription)")
                }
                group.leave()
            }
        case .page:
            NotionAPI.shared.fetchPages { result in
                group.leave()
            }
        }
        group.wait()
    }
}




//
//NotionAPI.shared.fetchDatabases { result in
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
//}
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
//group.wait()
