//
//  OutlineRenderer.swift
//  hunch
//

import Foundation

/// One line per item with its id, its type, and its text, so the id of a block can be found by what
/// the block says. Each level of block nesting is indented two spaces. It walks each block's children
/// itself to know their depth, so it expects the block tree and not a flattened list.
public class OutlineRenderer: Renderer {

    public init() {}

    public func render(_ items: [NotionItem]) throws -> String {
        var lines: [String] = []
        for item in items {
            appendLines(for: item, depth: 0, to: &lines)
        }
        return lines.joined(separator: "\n")
    }

    private func appendLines(for item: NotionItem, depth: Int, to lines: inout [String]) {
        let indent = String(repeating: "  ", count: depth)
        guard let block = item as? Block else {
            // A user with no name describes itself by its id, which the line already starts with
            let text = item.description == item.id ? "" : item.description
            lines.append(indent + Self.line(id: item.id, kind: item.object, text: text))
            return
        }

        var text = block.plainText
        if case .toDo(let toDo) = block.blockTypeObject {
            let checkbox = toDo.checked ? "[x]" : "[ ]"
            text = text.isEmpty ? checkbox : checkbox + " " + text
        }
        lines.append(indent + Self.line(id: block.id, kind: block.type.rawValue, text: text))

        for child in block.children {
            appendLines(for: child, depth: depth + 1, to: &lines)
        }
    }

    /// Every kind of line break inside the text is written as `\n` so each item stays on one line.
    /// Backslashes are doubled first, so a `\n` that was in the text still reads differently.
    private static func line(id: String, kind: String, text: String) -> String {
        let oneLineText = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: .newlines)
            .joined(separator: "\\n")
        return [id, kind, oneLineText].filter({ !$0.isEmpty }).joined(separator: " ")
    }
}
