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

    func run() async throws {
        var propsDict: [String: JSONValue] = [:]

        if let propertiesJSON = properties,
           let data = propertiesJSON.data(using: .utf8) {
            let parsed = try JSONDecoder().decode(JSONValue.self, from: data)
            if case .object(let dict) = parsed {
                propsDict = dict
            }
        }

        if let title = title {
            propsDict["title"] = .object([
                "title": .array([
                    .object(["text": .object(["content": .string(title)])])
                ])
            ])
        }

        let page = try await HunchAPI.shared.createPage(
            parentDatabaseId: database,
            properties: .object(propsDict)
        )
        try Hunch.output(list: [page], format: format)
    }
}
