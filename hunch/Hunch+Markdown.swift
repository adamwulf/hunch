//
//  Hunch+Markdown.swift
//  hunch
//
//  Created by Adam Wulf on 9/1/24.
//

import Foundation

extension Block {
    func toMarkdown() -> String {
        return renderBlockToMarkdown(self)
    }
}
func renderBlockToMarkdown(_ block: Block) -> String {
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
    return paragraphBlock.text.map { $0.plainText }.joined() + "\n\n"
}

private func renderHeading(_ block: Block, level: Int) -> String {
//    let headingBlock: HeadingBlock
//    switch block.blockTypeObject {
//    case .heading1(let block): headingBlock = block
//    case .heading2(let block): headingBlock = block
//    case .heading3(let block): headingBlock = block
//    default: return ""
//    }
    let text = block.children.map { renderBlockToMarkdown($0) }.joined()
    return String(repeating: "#", count: level) + " " + text + "\n\n"
}

private func renderBulletedListItem(_ block: Block) -> String {
    guard case let .bulletedListItem(bulletedListItemBlock) = block.blockTypeObject else { return "" }
    return "- " + bulletedListItemBlock.text + "\n"
}

private func renderNumberedListItem(_ block: Block) -> String {
    guard case let .numberedListItem(numberedListItemBlock) = block.blockTypeObject else { return "" }
    return "1. " + numberedListItemBlock.text + "\n"
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
