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

    enum Format: String, ExpressibleByArgument {
        case jsonl
        case id
    }

    static var configuration = CommandConfiguration(
        commandName: "hunch",
        version: "Hunch",
        subcommands: [DatabaseCommand.self, PageCommand.self, BlocksCommand.self]
    )

    init() {
        guard let key = ProcessInfo.processInfo.environment["NOTION_KEY"] else {
            fatalError("NOTION_KEY must be defined in environment")
        }
        Logging.configure()
        NotionAPI.shared.token = key
    }

    static func output(list: [NotionItem], format: Format) {
        switch format {
        case .id:
            for item in list {
                print(item.id)
            }
        case .jsonl:
            do {
                let ret = try list.map({ ["object": $0.object, "id": $0.id, "description": $0.description ] }).compactMap({
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
