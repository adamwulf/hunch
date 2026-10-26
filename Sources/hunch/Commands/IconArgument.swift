//
//  IconArgument.swift
//  hunch
//

import Foundation
import ArgumentParser
import HunchKit

/// Reads the value of `--icon`: an emoji, the URL of an image, or an icon object as JSON for the other
/// kinds of icon, like a custom emoji or a built-in Notion icon.
enum IconArgument {
    static let help = ArgumentHelp(
        "The page icon: an emoji, an image URL, or icon JSON",
        discussion: #"For example 🐞, https://example.com/icon.png, or '{"type":"icon","icon":{"name":"pizza","color":"blue"}}'"#
    )

    static func icon(from argument: String) throws -> Icon {
        let value = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw ValidationError("Give --icon an emoji, an image URL, or icon JSON")
        }
        if value.hasPrefix("{") {
            return try icon(fromJSON: Data(value.utf8))
        }
        if value.hasPrefix("https://") || value.hasPrefix("http://") {
            return .external(url: value)
        }
        return .emoji(value)
    }

    private static func icon(fromJSON data: Data) throws -> Icon {
        // A syntax error says so, instead of claiming the JSON has the wrong shape
        _ = try parseJSON(data)
        guard let icon = try? JSONDecoder().decode(Icon.self, from: data), let hasField = hasFieldForType(icon) else {
            throw ValidationError(
                #"--icon JSON must be an emoji, external, custom_emoji, or icon object, like {"type":"icon","icon":{"name":"pizza"}}"#
            )
        }
        guard hasField else {
            throw ValidationError("--icon JSON of type \"\(icon.type)\" needs the \"\(icon.type)\" field")
        }
        return icon
    }

    /// Whether the icon has the field its `type` names, which Notion needs to set it. Nil for a type that `--icon`
    /// can't set, like `file_upload`, whose field Icon doesn't keep.
    private static func hasFieldForType(_ icon: Icon) -> Bool? {
        switch icon.type {
        case "emoji":
            return icon.emoji != nil
        case "external":
            return icon.external != nil
        case "custom_emoji":
            return icon.customEmoji != nil
        case "icon":
            return icon.native != nil
        default:
            return nil
        }
    }
}
