//
//  main.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//

import Foundation
import ArgumentParser

@main
struct Hunch: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "duck",
        version: "Developer Duck",
        subcommands: [Fetch.self]
    )
}

struct Fetch: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "fetch",
        abstract: "Fetch pages or databases from Notion"
    )

    var token: String {
        guard let key = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            fatalError("NOTION_KEY must be defined in environment")
        }
        return key
    }

    func run() {
        let group = DispatchGroup() // initialize

        NotionAPI.shared.token = token
        group.enter()
        NotionAPI.shared.fetchDatabases { result in
            switch result {
            case .success(let dbs):
                for db in dbs.results {
                    print(db.plainTextTitle)
                }
            case .failure(let error):
                print(error)
            }
            group.leave()
        }
//        group.enter()
//        NotionAPI.shared.fetchPages { result in
//            switch result {
//            case .success(let pages):
//                for page in pages.results {
//                    print(page)
//                }
//            case .failure(let error):
//                print(error)
//            }
//            group.leave()
//        }
        group.wait()
    }
}
