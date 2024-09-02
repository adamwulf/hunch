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
        case smalljsonl
        case jsonl
        case id
        case markdown
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
        // Flatten the list of NotionItems
        let flattenedList = flatten(items: list)

        switch format {
        case .id:
            for item in flattenedList {
                print(item.id)
            }
        case .smalljsonl:
            do {
                let ret = try flattenedList.map({
                    var ret: [String: Any] = ["object": $0.object, "id": $0.id, "description": $0.description]
                    if let parent = $0.parent?.asDictionary() {
                        ret["parent"] = parent
                    }
                    return ret
                }).compactMap({
                    let data = try JSONSerialization.data(withJSONObject: $0, options: .sortedKeys)
                    return String(data: data, encoding: .utf8)
                })
                for line in ret {
                    print(line)
                }
            } catch {
                print("error: \(error.localizedDescription)")
            }
        case .jsonl:
            do {
                let encoder = JSONEncoder()
                let ret = try flattenedList.compactMap({
                    let data = try encoder.encode($0)
                    return String(data: data, encoding: .utf8)
                })
                for line in ret {
                    print(line)
                }
            } catch {
                print("error: \(error.localizedDescription)")
            }
        case .markdown:
            var markdown = ""
            for item in flattenedList {
                guard let item = item as? Block else {
                    fatalError("Only Blocks can be rendered to markdown.")
                }
                markdown += renderBlockToMarkdown(item)
            }
            print(markdown)
        }
    }

    // Helper function to flatten the list of NotionItems
    private static func flatten(items: [NotionItem]) -> [NotionItem] {
        var flattenedList: [NotionItem] = []

        for item in items {
            flattenedList.append(item)
            if let block = item as? Block {
                flattenedList.append(contentsOf: flatten(items: block.children))
            }
        }

        return flattenedList
    }
}
