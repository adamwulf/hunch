//
//  DatabaseCommand.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox
import HunchKit

struct DatabaseCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "database",
        abstract: "Fetch databases from Notion"
    )

    @Argument(help: "The Notion id of the object") var entityId: String?

    @Option(name: .shortAndLong, help: "The maxiumum number of results to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    @Flag(name: .long, help: "Retrieve a single database schema by ID (requires entityId)")
    var schema: Bool = false

    func run() async {
        do {
            if schema {
                guard let databaseId = entityId else {
                    print("error: --schema requires a database ID as argument")
                    return
                }
                let database = try await HunchAPI.shared.retrieveDatabase(databaseId: databaseId)
                Hunch.output(list: [database], format: format)
            } else {
                let limit = limit ?? .max
                let databases = try await HunchAPI.shared.fetchDatabases(parentId: entityId, limit: limit)
                Hunch.output(list: databases, format: format)
            }
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
