//
//  main.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//

import Foundation
import ArgumentParser
import SwiftToolbox
import HunchKit

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
        subcommands: [DatabaseCommand.self, PageCommand.self, BlocksCommand.self, ExportCommand.self, ExportPageCommand.self, ActivityCommand.self, UpdatePageCommand.self, CreatePageCommand.self, CommentsCommand.self, SearchCommand.self, AppendBlocksCommand.self, DeleteBlockCommand.self]
    )

    static func output(list: [NotionItem], format: Format, ignoreColor: Bool = false, ignoreUnderline: Bool = false) {
        let flattenedList = flatten(items: list)

        let renderer: Renderer = {
            switch format {
            case .id:
                return IDRenderer()
            case .smalljsonl:
                return SmallJSONRenderer()
            case .jsonl:
                return FullJSONRenderer()
            case .markdown:
                return MarkdownRenderer(level: 0, ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline)
            }
        }()

        do {
            let output = try renderer.render(flattenedList)
            print(output)
        } catch {
            print("error: \(error.localizedDescription)")
        }
    }

    // Helper function to flatten the list of NotionItems
    private static func flatten(items: [NotionItem]) -> [NotionItem] {
        var flattenedList: [NotionItem] = []

        for item in items {
            flattenedList.append(item)
            if let block = item as? Block {
                flattenedList.append(contentsOf: flatten(items: block.childrenToFlatten))
            }
        }

        return flattenedList
    }
}
