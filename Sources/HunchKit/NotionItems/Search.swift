//
//  Search.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation

public struct SearchFilter: Codable {
    public let value: String
    public let property: String

    public init(value: String, property: String = "object") {
        self.value = value
        self.property = property
    }
}

public struct SearchSort: Codable {
    public let direction: Direction
    public let timestamp: Timestamp

    public enum Direction: String, Codable {
        case ascending
        case descending
    }

    public enum Timestamp: String, Codable {
        case lastEditedTime = "last_edited_time"
    }

    public init(direction: Direction, timestamp: Timestamp = .lastEditedTime) {
        self.direction = direction
        self.timestamp = timestamp
    }
}

public enum SearchResultItem: Codable {
    case page(Page)
    case database(Database)

    public var asNotionItem: NotionItem {
        switch self {
        case .page(let page): return page
        case .database(let database): return database
        }
    }

    private enum CodingKeys: String, CodingKey {
        case object
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let object = try container.decode(String.self, forKey: .object)

        switch object {
        case "page":
            self = .page(try Page(from: decoder))
        case "database":
            self = .database(try Database(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .object,
                in: container,
                debugDescription: "Unknown search result object type: \(object)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .page(let page):
            try page.encode(to: encoder)
        case .database(let database):
            try database.encode(to: encoder)
        }
    }
}

struct SearchResults: Codable {
    let object = "list"
    let results: [SearchResultItem]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}
