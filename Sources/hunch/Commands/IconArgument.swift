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
            do {
                return try JSONDecoder().decode(Icon.self, from: Data(value.utf8))
            } catch {
                throw ValidationError(#"The --icon JSON must be an icon object, like {"type":"icon","icon":{"name":"pizza"}}"#)
            }
        }
        if value.hasPrefix("https://") || value.hasPrefix("http://") {
            return .external(url: value)
        }
        return .emoji(value)
    }
}
