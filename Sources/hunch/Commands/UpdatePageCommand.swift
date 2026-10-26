//
//  UpdatePageCommand.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation
import ArgumentParser
import HunchKit

struct UpdatePageCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "update-page",
        abstract: "Update properties of an existing page"
    )

    @Argument(help: "The Notion page ID to update")
    var pageId: String

    @Option(name: .long, help: "Properties as a JSON string")
    var properties: String?

    @Flag(name: .long, help: "Archive (trash) the page")
    var archive: Bool = false

    @Flag(name: .long, help: "Unarchive (restore) the page")
    var unarchive: Bool = false

    @Option(name: .long, help: IconArgument.help)
    var icon: String?

    @Flag(name: .long, help: "Remove the page icon")
    var removeIcon: Bool = false

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        var props: JSONValue?
        if let propertiesJSON = properties,
           let data = propertiesJSON.data(using: .utf8) {
            props = try JSONDecoder().decode(JSONValue.self, from: data)
        }

        let archived: Bool? = archive ? true : (unarchive ? false : nil)
        let iconUpdate = try Self.iconUpdate(icon: icon, removeIcon: removeIcon)

        guard props != nil || archived != nil || iconUpdate != nil else {
            throw ValidationError("Provide --properties, --icon/--remove-icon, and/or --archive/--unarchive")
        }

        let page = try await HunchAPI.shared.updatePage(pageId: pageId, properties: props, archived: archived, icon: iconUpdate)
        try Hunch.output(list: [page], format: format)
    }

    /// The change to the page icon, or nil to leave the icon as it is
    static func iconUpdate(icon: String?, removeIcon: Bool) throws -> Icon.Update? {
        if removeIcon {
            guard icon == nil else {
                throw ValidationError("Give --icon or --remove-icon, not both")
            }
            return .remove
        }
        return try icon.map { .set(try IconArgument.icon(from: $0)) }
    }
}
