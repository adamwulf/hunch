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
        _ = try parseJSON(data, name: "--icon")
        let notAnIcon = ValidationError(
            #"--icon JSON must be an emoji, external, custom_emoji, or icon object, like {"type":"icon","icon":{"name":"pizza"}}"#
        )
        guard let icon = try? JSONDecoder().decode(Icon.self, from: data) else {
            throw notAnIcon
        }
        // Notion refuses an icon without the field its type names. Icon drops the fields it doesn't know, so a type
        // like file_upload would reach Notion without its field.
        let hasField: Bool
        switch icon.type {
        case "emoji":
            hasField = icon.emoji != nil
        case "external":
            hasField = icon.external != nil
        case "custom_emoji":
            hasField = icon.customEmoji != nil
        case "icon":
            hasField = icon.native != nil
        default:
            throw notAnIcon
        }
        guard hasField else {
            throw ValidationError("--icon JSON of type \"\(icon.type)\" needs the \"\(icon.type)\" field")
        }
        return icon
    }
}
