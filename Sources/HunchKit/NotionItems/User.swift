//
//  User.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

public struct User: Codable {
    public enum Kind: String, Codable {
        case person
        case bot
    }

    public let object = "user"
    public let id: String
    public let type: Kind
    public let name: String?
    public let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case avatarURL = "avatar_url"
    }
}
