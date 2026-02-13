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
    var properties: String

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
            guard let data = properties.data(using: .utf8),
                  let props = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("error: invalid properties JSON")
                return
            }

            let page = try await HunchAPI.shared.updatePage(pageId: pageId, properties: props)
            Hunch.output(list: [page], format: format)
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
