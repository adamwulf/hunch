//
//  DotEnv.swift
//  hunch
//

import Foundation

/// Parses `.env` files for key-value pairs.
public enum DotEnv {

    /// Loads a value for the given key from a `.env` file, searching from `directory` upward
    /// through parent directories until the filesystem root is reached.
    ///
    /// - Parameters:
    ///   - key: The environment variable name to look for (e.g. `"NOTION_KEY"`)
    ///   - directory: The directory to start searching from. Defaults to the current working directory.
    /// - Returns: The value if found, or `nil`.
    public static func loadValue(forKey key: String, startingIn directory: URL? = nil) -> String? {
        var dir = directory ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        while true {
            let envFileURL = dir.appendingPathComponent(".env")
            if let value = parseValue(forKey: key, in: envFileURL) {
                return value
            }

            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path {
                break
            }
            dir = parent
        }
        return nil
    }

    /// Parses a single `.env` file and returns the value for the given key, or `nil`.
    public static func parseValue(forKey key: String, in fileURL: URL) -> String? {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }

        let prefix = key + "="
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            if trimmed.hasPrefix(prefix) {
                var value = String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
                // Strip surrounding quotes (single or double)
                if value.count >= 2 {
                    let first = value.first
                    let last = value.last
                    if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                        value = String(value.dropFirst().dropLast())
                    }
                }
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }
}
