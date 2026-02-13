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

    @Option(name: .long, help: "Filter as JSON string (e.g. '{\"property\":\"Status\",\"status\":{\"equals\":\"Done\"}}')")
    var filter: String?

    @Option(name: .long, help: "Sort property name")
    var sortBy: String?

    @Option(name: .long, help: "Sort direction: ascending or descending (default: ascending)")
    var sortDirection: String?

    @Option(name: .long, help: "Sort by timestamp: created_time or last_edited_time")
    var sortTimestamp: String?

    func run() async {
        do {
            if let pageId = id {
                let page = try await HunchAPI.shared.retrievePage(pageId: pageId)
                Hunch.output(list: [page], format: format)
            } else {
                let limit = limit ?? .max

                var dbFilter: DatabaseFilter?
                if let filterJSON = filter, let filterData = filterJSON.data(using: .utf8) {
                    dbFilter = try JSONDecoder().decode(DatabaseFilter.self, from: filterData)
                }

                var dbSorts: [DatabaseSort]?
                if let sortBy = sortBy {
                    let direction: DatabaseSort.Direction = sortDirection == "descending" ? .descending : .ascending
                    dbSorts = [DatabaseSort(property: sortBy, direction: direction)]
                } else if let sortTimestamp = sortTimestamp {
                    let direction: DatabaseSort.Direction = sortDirection == "descending" ? .descending : .ascending
                    if let ts = DatabaseSort.TimestampSort(rawValue: sortTimestamp) {
                        dbSorts = [DatabaseSort(timestamp: ts, direction: direction)]
                    }
                }

                let pages = try await HunchAPI.shared.fetchPages(databaseId: database, limit: limit, filter: dbFilter, sorts: dbSorts)
                Hunch.output(list: pages, format: format)
            }
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
