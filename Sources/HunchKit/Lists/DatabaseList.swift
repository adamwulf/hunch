//
//  DatabaseList.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

struct DatabaseList: Codable {
    let object = "list"
    let results: [Database]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}
