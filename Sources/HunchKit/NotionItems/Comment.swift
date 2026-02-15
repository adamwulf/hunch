//
//  Comment.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation

public struct Comment: NotionItem {
    public internal(set) var object: String
    public internal(set) var id: String
    public internal(set) var parent: Parent?
    public internal(set) var discussionId: String
    public internal(set) var createdTime: String
    public internal(set) var lastEditedTime: String
    public internal(set) var createdBy: PartialUser
    public internal(set) var richText: [RichText]

    public var description: String {
        return richText.map({ $0.plainText }).joined()
    }

    enum CodingKeys: String, CodingKey {
        case object
        case id
        case parent
        case discussionId = "discussion_id"
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case createdBy = "created_by"
        case richText = "rich_text"
    }
}
