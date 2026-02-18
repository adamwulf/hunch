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

    public struct PersonInfo: Codable {
        public internal(set) var email: String?
    }

    public struct BotOwner: Codable {
        public internal(set) var type: String
        public internal(set) var workspace: Bool?

        enum CodingKeys: String, CodingKey {
            case type
            case workspace
        }
    }

    public struct BotInfo: Codable {
        public internal(set) var owner: BotOwner?
    }

    public let object = "user"
    public internal(set) var id: String
    public internal(set) var parent: Parent?
    public internal(set) var type: Kind
    public internal(set) var name: String?
    public internal(set) var avatarURL: String?
    public internal(set) var person: PersonInfo?
    public internal(set) var bot: BotInfo?

    public var description: String {
        return name ?? id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case avatarURL = "avatar_url"
        case person
        case bot
    }
}
