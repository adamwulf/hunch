//
//  User.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

struct User: Codable {
    enum Kind: String, Codable {
        case person
        case bot
    }

    let object = "user"
    let id: String
    let type: Kind
    let name: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case avatarURL = "avatar_url"
    }
}
