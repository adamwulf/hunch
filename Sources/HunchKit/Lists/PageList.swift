//
//  PageList.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

struct PageList: Codable {
    let object = "list"
    let results: [Page]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case results
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}
