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

    enum Format: String, ExpressibleByArgument, CaseIterable {
        case smalljsonl
        case jsonl
        case json
        case id
        case markdown
        case outline
    }

    enum SortDirection: String, ExpressibleByArgument, CaseIterable {
        case ascending
        case descending
    }

    static var configuration = CommandConfiguration(
        commandName: "hunch",
        abstract: "A CLI tool for interacting with the Notion API",
        version: "Hunch",
        subcommands: [
            DatabaseCommand.self,
            PageCommand.self,
            BlocksCommand.self,
            ExportCommand.self,
            ExportPageCommand.self,
            ActivityCommand.self,
            UpdatePageCommand.self,
            CreatePageCommand.self,
            CommentsCommand.self,
            SearchCommand.self,
            AppendBlocksCommand.self,
            UpdateBlockCommand.self,
            DeleteBlockCommand.self,
            UsersCommand.self
        ]
    )

    static func main() async {
        // Load NOTION_KEY from a .env file if the environment variable is not set
        if NotionAPI.shared.token == nil {
            NotionAPI.shared.token = DotEnv.loadValue(forKey: "NOTION_KEY")
        }

        // Every command that touches YouTube presents the same client, so this belongs here rather
        // than in the one command that fetches the most
        YouTubeIdentity.install()

        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            exit(withError: error)
        }
    }

    static func output(list: [NotionItem], format: Format, ignoreColor: Bool = false, ignoreUnderline: Bool = false) throws {
        print(try render(list: list, format: format, ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline))
    }

    static func render(list: [NotionItem], format: Format, ignoreColor: Bool = false, ignoreUnderline: Bool = false) throws -> String {
        // The outline shows nesting by indent, so it walks the block tree itself. Every other format gets
        // each block followed by its children in one flat list.
        let items = format == .outline ? list : flatten(items: list)

        let renderer: Renderer = {
            switch format {
            case .id:
                return IDRenderer()
            case .smalljsonl:
                return SmallJSONRenderer()
            case .jsonl:
                return FullJSONRenderer()
            case .json:
                return JSONRenderer()
            case .markdown:
                return MarkdownRenderer(level: 0, ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline)
            case .outline:
                return OutlineRenderer()
            }
        }()

        return try renderer.render(items)
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
