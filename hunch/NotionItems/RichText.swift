//
//  RichText.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

struct RichText: Codable {

    struct Text: Codable {
        let content: String
        let link: Link?
    }

    struct Mention: Codable {
        let type: Kind
        let user: User?
        let page: Reference?
        let database: Reference?
        let date: NotionDate?

        enum Kind: String, Codable {
            case user
            case page
            case database
            case date
        }
    }

    let plainText: String
    var href: String?
    var annotations: Annotation
    var type: String

    var text: Text?

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case href
        case annotations
        case type
        case text
    }
}

struct Reference: Codable {
    var id: String
}

struct Link: Codable {
    let type = "url"
    let url: String

    enum CodingKeys: String, CodingKey {
        case url
    }
}

struct NotionDate: Codable {
    let start: String
    let end: String?
}

struct Annotation: Codable {
    var bold: Bool
    var italic: Bool
    var strikethrough: Bool
    var underline: Bool
    var code: Bool
    var color: Color
}
