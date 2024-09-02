//
//  Hunch+Markdown.swift
//  hunch
//
//  Created by Adam Wulf on 9/1/24.
//

import Foundation
import SwiftToolbox

class MarkdownRenderer {
    private(set) var level: Int
    let ignoreColor: Bool
    let ignoreUnderline: Bool

    private var listState: Bool = false

    init(level: Int, ignoreColor: Bool, ignoreUnderline: Bool) {
        self.level = level
        self.ignoreColor = ignoreColor
        self.ignoreUnderline = ignoreUnderline
    }

    private func childRenderer(level levelOverride: Int? = nil) -> MarkdownRenderer {
        return MarkdownRenderer(level: levelOverride ?? (level + 1), ignoreColor: ignoreColor, ignoreUnderline: ignoreUnderline)
    }

    func renderBlocksToMarkdown(_ blocks: [Block]) -> String {
        var markdown = ""
        for block in blocks {
            markdown += handleStateForBlock(block)
            markdown += renderBlockToMarkdown(block)
        }
        return markdown
    }

    private func handleStateForBlock(_ block: Block) -> String {
        var ret = ""
        switch block.type {
        case .bulletedListItem, .numberedListItem:
            listState = true
        default:
            if listState {
                // we've ended our list, so append an extra newline to start a new paragraph
                ret += "\n"
            }
            listState = false
        }
        return ret
    }

    private func renderBlockToMarkdown(_ block: Block) -> String {
        switch block.type {
        case .paragraph:
            return renderParagraph(block)
        case .heading1:
            return renderHeading(block, level: 1)
        case .heading2:
            return renderHeading(block, level: 2)
        case .heading3:
            return renderHeading(block, level: 3)
        case .bulletedListItem:
            return renderBulletedListItem(block)
        case .numberedListItem:
            return renderNumberedListItem(block)
        case .toDo:
            return renderToDo(block)
        case .toggle:
            return renderToggle(block)
    //    case .code:
    //        return renderCode(block)
        case .quote:
            return renderQuote(block)
        case .callout:
            return renderCallout(block)
        case .divider:
            return "---\n"
        case .image:
            return renderImage(block)
        case .video:
            return renderVideo(block)
        case .file:
            return renderFile(block)
        case .bookmark:
            return renderBookmark(block)
        // Add more cases for other block types as needed
        default:
            return "Unsupported block type: \(block.type.rawValue)\n"
        }
    }

    private func renderParagraph(_ block: Block) -> String {
        guard case let .paragraph(paragraphBlock) = block.blockTypeObject else { return "" }
        let formattedText = paragraphBlock.text.map { renderRichText($0) }.joined()
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer(level: 0)
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return formattedText + "\n\n" + childrenText
    }

    private func renderRichText(_ richText: RichText) -> String {
        var text = richText.plainText

        // Apply annotations
        if richText.annotations.bold { text = "**\(text)**" }
        if richText.annotations.italic { text = "_\(text)_" }
        if richText.annotations.strikethrough { text = "~~\(text)~~" }
        if richText.annotations.code { text = "`\(text)`" }
        if !ignoreUnderline, richText.annotations.underline { text = "<u>\(text)</u>" }

        // Apply color if it's not default
        if !ignoreColor, richText.annotations.color != .plain {
            text = "<span style=\"color: \(richText.annotations.color.rawValue)\">\(text)</span>"
        }

        // Apply link if present
        if let href = richText.href {
            text = "[\(text)](\(href))"
        }

        return text
    }

    private func renderHeading(_ block: Block, level: Int) -> String {
        let formattedText: String
        switch block.blockTypeObject {
        case .heading1(let block):
            formattedText = block.text.map { renderRichText($0) }.joined()
        case .heading2(let block):
            formattedText = block.text.map { renderRichText($0) }.joined()
        case .heading3(let block):
            formattedText = block.text.map { renderRichText($0) }.joined()
        default:
            fatalError("Invalid header block")
        }
        return String(repeating: "#", count: level) + " " + formattedText + "\n\n"
    }

    private func renderBulletedListItem(_ block: Block) -> String {
        guard case let .bulletedListItem(bulletedListItemBlock) = block.blockTypeObject else { return "" }
        let formattedText = bulletedListItemBlock.text.map { renderRichText($0) }.joined()
        let indentation = String(repeating: " ", count: level * 4)
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer()
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return indentation + "- " + formattedText + "\n" + childrenText
    }

    private func renderNumberedListItem(_ block: Block) -> String {
        guard case let .bulletedListItem(bulletedListItemBlock) = block.blockTypeObject else { return "" }
        let formattedText = bulletedListItemBlock.text.map { renderRichText($0) }.joined()
        let indentation = String(repeating: " ", count: level * 4)
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer()
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return indentation + "1. " + formattedText + "\n" + childrenText
    }

    private func renderToDo(_ block: Block) -> String {
        guard case let .toDo(toDoBlock) = block.blockTypeObject else { return "" }
        let checkbox = toDoBlock.checked ? "[x]" : "[ ]"
        return "- \(checkbox) " + toDoBlock.text + "\n"
    }

    private func renderToggle(_ block: Block) -> String {
        guard case let .toggle(toggleBlock) = block.blockTypeObject else { return "" }
        return "<details><summary>" + toggleBlock.text + "</summary>\n\n" +
               block.children.map { renderBlockToMarkdown($0) }.joined() +
               "</details>\n\n"
    }

    private func renderCode(_ block: Block) -> String {
        fatalError("not yet implemented")
    //    guard case let .code(codeBlock) = block.blockTypeObject else { return "" }
    //    return "```\(codeBlock.language)\n" + codeBlock.text + "\n```\n\n"
    }

    private func renderQuote(_ block: Block) -> String {
        guard case let .quote(quoteBlock) = block.blockTypeObject else { return "" }
        return "> " + quoteBlock.text.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
    }

    private func renderCallout(_ block: Block) -> String {
        fatalError("not yet implemented")
    //    guard case let .callout(calloutBlock) = block.blockTypeObject else { return "" }
    //    let icon = calloutBlock.icon?.emoji ?? "ℹ️"
    //    return "> \(icon) " + calloutBlock.text.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
    }

    private func renderImage(_ block: Block) -> String {
        fatalError("not yet implemented")
    //    guard case let .image(imageBlock) = block.blockTypeObject else { return "" }
    //    let caption = imageBlock.caption.isEmpty ? "Image" : imageBlock.caption
    //    return "![\(caption)](\(imageBlock.url))\n\n"
    }

    private func renderVideo(_ block: Block) -> String {
        guard case let .video(videoBlock) = block.blockTypeObject else { return "" }
        return "Video: [\(videoBlock.url)](\(videoBlock.url))\n\n"
    }

    private func renderFile(_ block: Block) -> String {
        fatalError("not yet implemented")
    //    guard case let .file(fileBlock) = block.blockTypeObject else { return "" }
    //    return "File: [\(fileBlock.name)](\(fileBlock.url))\n\n"
    }

    private func renderBookmark(_ block: Block) -> String {
        guard case let .bookmark(bookmarkBlock) = block.blockTypeObject else { return "" }
        return "[\(bookmarkBlock.url)](\(bookmarkBlock.url))\n\n"
    }

}
