//
//  User.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

public struct User: NotionItem {
    public enum Kind: String, Codable {
        case person
        case bot
    }

    public internal(set) var object: String
    public internal(set) var id: String
    public internal(set) var parent: Parent?
    public internal(set) var type: Kind
    public internal(set) var name: String?
    public internal(set) var avatarURL: String?

    public var description: String {
        return name ?? id
    }

    enum CodingKeys: String, CodingKey {
        case object
        case id
        case type
        case name
        case avatarURL = "avatar_url"
    }
}
