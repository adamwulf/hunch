//
//  SearchCommand.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation
import ArgumentParser
import HunchKit

struct SearchCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search across all pages and databases"
    )

    @Argument(help: "The search query text")
    var query: String?

    @Option(name: .shortAndLong, help: "Filter by object type: page or database")
    var filterType: String?

    @Option(name: .long, help: "Sort direction: ascending or descending")
    var sortDirection: String?

    @Option(name: .shortAndLong, help: "The maximum number of results to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
            let filter: SearchFilter? = filterType.map { SearchFilter(value: $0) }

            let sort: SearchSort? = sortDirection.map { dir in
                let direction: SearchSort.Direction = dir == "descending" ? .descending : .ascending
                return SearchSort(direction: direction)
            }

            let limit = limit ?? .max
            let items = try await HunchAPI.shared.search(query: query, filter: filter, sort: sort, limit: limit)
            Hunch.output(list: items, format: format)
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
