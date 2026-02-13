//
//  CommentList.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation

struct CommentList: Codable {
    let object = "list"
    let results: [Comment]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}
