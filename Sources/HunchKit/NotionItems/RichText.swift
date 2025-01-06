//
//  RichText.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

public struct RichText: Codable {

    public struct Text: Codable {
        public let content: String
        public let link: Link?

        public init(content: String, link: Link? = nil) {
            self.content = content
            self.link = link
        }
    }

    public struct Mention: Codable {
        public let type: Kind
        public let user: User?
        public let page: Reference?
        public let database: Reference?
        public let date: NotionDate?

        public enum Kind: String, Codable {
            case user
            case page
            case database
            case date
        }
    }

    public let plainText: String
    public internal(set) var href: String?
    public internal(set) var annotations: Annotation
    public internal(set) var type: String
    public internal(set) var text: Text?

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
        case href
        case annotations
        case type
        case text
    }

    public init(plainText: String, href: String? = nil, annotations: Annotation, type: String, text: Text? = nil) {
        self.plainText = plainText
        self.href = href
        self.annotations = annotations
        self.type = type
        self.text = text
    }
}

public struct Reference: Codable {
    public internal(set) var id: String
}

public struct Link: Codable {
    public let type = "url"
    public let url: String

    enum CodingKeys: String, CodingKey {
        case url
    }
}

public struct NotionDate: Codable {
    public let start: String
    public let end: String?
}

public struct Annotation: Codable, Equatable {
    public internal(set) var bold: Bool
    public internal(set) var italic: Bool
    public internal(set) var strikethrough: Bool
    public internal(set) var underline: Bool
    public internal(set) var code: Bool
    public internal(set) var color: Color

    public static let plain = Annotation(
        bold: false,
        italic: false,
        strikethrough: false,
        underline: false,
        code: false,
        color: .plain
    )
}
