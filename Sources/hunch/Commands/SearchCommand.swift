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

    enum FilterType: String, ExpressibleByArgument, CaseIterable {
        case page
        case database
    }

    static var configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search across all pages and databases"
    )

    @Argument(help: "The search query text")
    var query: String?

    @Option(name: .long, help: "Filter by object type")
    var filterType: FilterType?

    @Option(name: .long, help: "Sort direction")
    var sortDirection: Hunch.SortDirection?

    @Option(name: .shortAndLong, help: "The maximum number of results to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        let filter: SearchFilter? = filterType.map { SearchFilter(value: $0.rawValue) }

        let sort: SearchSort? = sortDirection.map { dir in
            let direction: SearchSort.Direction = dir == .descending ? .descending : .ascending
            return SearchSort(direction: direction)
        }

        let limit = limit ?? .max
        let items = try await HunchAPI.shared.search(query: query, filter: filter, sort: sort, limit: limit)
        Hunch.output(list: items, format: format)
    }
}
