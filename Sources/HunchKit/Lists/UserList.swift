//
//  UserList.swift
//  hunch
//
//  Created by Adam Wulf on 2/17/26.
//

import Foundation

struct UserList: Codable {
    let object = "list"
    let results: [User]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }

    var simpleList: (next: String?, items: [User]) {
        return (next: hasMore ? nextCursor : nil, items: results)
    }
}
