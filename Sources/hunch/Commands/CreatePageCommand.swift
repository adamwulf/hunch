//
//  CreatePageCommand.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation
import ArgumentParser
import HunchKit

struct CreatePageCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "create-page",
        abstract: "Create a new page in a database"
    )

    @Option(name: .shortAndLong, help: "The parent database ID")
    var database: String

    @Option(name: .shortAndLong, help: "Page title")
    var title: String?

    @Option(name: .long, help: "Properties as a JSON string")
    var properties: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
            var props: [String: Any] = [:]

            if let propertiesJSON = properties,
               let data = propertiesJSON.data(using: .utf8),
               let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                props = parsed
            }

            if let title = title {
                props["Name"] = [
                    "title": [
                        ["text": ["content": title]]
                    ]
                ]
            }

            let page = try await HunchAPI.shared.createPage(parentDatabaseId: database, properties: props)
            Hunch.output(list: [page], format: format)
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
