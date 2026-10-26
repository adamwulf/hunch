//
//  Icon.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

/// The icon of a page, database, or callout block. `type` says which one of the other fields is set.
/// https://developers.notion.com/reference/emoji-and-icon
public struct Icon: Codable {
    public internal(set) var type: String
    public internal(set) var emoji: String?
    public internal(set) var file: File?
    public internal(set) var external: External?
    public internal(set) var customEmoji: CustomEmoji?
    public internal(set) var native: Native?

    public static func emoji(_ emoji: String) -> Icon {
        return Icon(type: "emoji", emoji: emoji)
    }

    public static func external(url: String) -> Icon {
        return Icon(type: "external", external: External(url: url))
    }

    /// The custom emoji must belong to the same workspace as the integration.
    public static func customEmoji(id: String) -> Icon {
        return Icon(type: "custom_emoji", customEmoji: CustomEmoji(id: id))
    }

    /// `name` can be the icon's API name or the name in Notion's icon picker. Notion uses gray when `color` is nil.
    public static func native(name: String, color: String? = nil) -> Icon {
        return Icon(type: "icon", native: Native(name: name, color: color))
    }

    /// How a page update changes the page's icon.
    public enum Update {
        case set(Icon)
        case remove
    }

    enum CodingKeys: String, CodingKey {
        case type
        case emoji
        case file
        case external
        case customEmoji = "custom_emoji"
        case native = "icon"
    }

    public struct File: Codable {
        public internal(set) var url: String
        public internal(set) var expiryTime: Date?

        enum CodingKeys: String, CodingKey {
            case url
            case expiryTime = "expiry_time"
        }
    }

    public struct External: Codable {
        public internal(set) var url: String
    }

    /// An emoji uploaded to the workspace. Notion only reads `id` when setting an icon.
    public struct CustomEmoji: Codable {
        public internal(set) var id: String
        public internal(set) var name: String?
        public internal(set) var url: String?
    }

    /// A built-in Notion icon, with `type` "icon".
    public struct Native: Codable {
        public internal(set) var name: String
        public internal(set) var color: String?
    }
}
