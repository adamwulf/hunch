//
//  PageCommand.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox

struct PageCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "page",
        abstract: "Fetch pages from Notion"
    )

    @Option(name: .shortAndLong, help: "The Notion id of the object") var database: String?

    @Option(name: .shortAndLong, help: "The maxiumum number of results to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
            let limit = limit ?? .max
            let pages = try await HunchAPI.shared.fetchPages(databaseId: database, limit: limit)
            Hunch.output(list: pages, format: format)
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
