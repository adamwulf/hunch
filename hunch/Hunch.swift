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

    static func output(list: [NotionItem], format: Format, ignoreColor: Bool = false, ignoreUnderline: Bool = false) {
        let flattenedList = flatten(items: list)

        switch format {
        case .id:
            for item in flattenedList {
                print(item.id)
            }
        case .smalljsonl:
            do {
                let renderer = SmallJSONRenderer()
                let lines = try renderer.render(flattenedList)
                lines.forEach { print($0) }
            } catch {
                print("error: \(error.localizedDescription)")
            }
        case .jsonl:
            do {
                let renderer = FullJSONRenderer()
                let lines = try renderer.render(flattenedList)
                lines.forEach { print($0) }
            } catch {
                print("error: \(error.localizedDescription)")
            }
        case .markdown:
            let renderer = MarkdownRenderer(level: 0, ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline)
            let markdown = renderer.renderBlocksToMarkdown(list.compactMap({ $0 as? Block }))
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
