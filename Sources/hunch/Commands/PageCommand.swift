//
//  PageCommand.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import Foundation
import ArgumentParser
import SwiftToolbox
import HunchKit

struct PageCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "page",
        abstract: "Fetch pages from Notion"
    )

    @Option(name: .shortAndLong, help: "The Notion id of a specific page") var id: String?

    @Option(name: .shortAndLong, help: "The Notion id of a database") var database: String?

    @Option(name: .shortAndLong, help: "The maxiumum number of results to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
            if let pageId = id {
                // Fetch single page by ID
                let page = try await HunchAPI.shared.retrievePage(pageId: pageId)
                Hunch.output(list: [page], format: format)
            } else {
                // Fetch pages from database
                let limit = limit ?? .max
                let pages = try await HunchAPI.shared.fetchPages(databaseId: database, limit: limit)
                Hunch.output(list: pages, format: format)
            }
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
