//
//  MarkdownRenderer.swift
//  hunch
//
//  Created by Adam Wulf on 9/1/24.
//

import Foundation
import SwiftToolbox

public class MarkdownRenderer: Renderer {
    private(set) var level: Int
    let ignoreColor: Bool
    let ignoreUnderline: Bool
    let downloadedAssets: [String: FileDownloader.DownloadedAsset]

    private var listState: Bool = false

    public init(level: Int,
                ignoreColor: Bool,
                ignoreUnderline: Bool,
                downloadedAssets: [String: FileDownloader.DownloadedAsset] = [:]) {
        self.level = level
        self.ignoreColor = ignoreColor
        self.ignoreUnderline = ignoreUnderline
        self.downloadedAssets = downloadedAssets
    }

    public func render(_ items: [NotionItem]) throws -> String {
        var markdown = ""
        for item in items {
            if let block = item as? Block {
                markdown += handleStateForBlock(block)
                markdown += renderBlockToMarkdown(block)
            } else if let database = item as? Database {
                markdown += renderDatabase(database)
            } else if let page = item as? Page {
                markdown += renderPage(page)
            } else if let comment = item as? Comment {
                markdown += renderComment(comment)
            }
        }
        return markdown
    }

    public func render(_ text: [RichText]) throws -> String {
        return text.map { renderRichText($0) }.joined()
    }

    private func childRenderer(level levelOverride: Int? = nil) -> MarkdownRenderer {
        return MarkdownRenderer(
            level: levelOverride ?? (level + 1),
            ignoreColor: ignoreColor,
            ignoreUnderline: ignoreUnderline,
            downloadedAssets: downloadedAssets
        )
    }

    private func renderBlocksToMarkdown(_ blocks: [Block]) -> String {
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
        case .bulletedListItem, .numberedListItem, .toDo:
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
        case .audio:
            return renderAudio(block)
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
        case .code:
            return renderCode(block)
        case .quote:
            return renderQuote(block)
        case .callout:
            return renderCallout(block)
        case .divider:
            return "---\n\n"
        case .image:
            return renderImage(block)
        case .video:
            return renderVideo(block)
        case .file:
            return renderFile(block)
        case .bookmark:
            return renderBookmark(block)
        case .childPage:
            return renderChildPage(block)
        case .table:
            return renderTable(block)
        case .linkToPage:
            return renderLinkToPage(block)
        case .breadcrumb:
            return ""
        case .embed:
            return renderEmbed(block)
        case .linkPreview:
            return renderLinkPreview(block)
        case .pdf:
            return renderPDF(block)
        case .childDatabase:
            return renderChildDatabase(block)
        case .columnList:
            return renderColumnList(block)
        case .column:
            return renderColumn(block)
        case .syncedBlock:
            return renderSyncedBlock(block)
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
        guard case let .numberedListItem(numberedListItemBlock) = block.blockTypeObject else { return "" }
        let formattedText = numberedListItemBlock.text.map { renderRichText($0) }.joined()
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
        let formattedText = toDoBlock.text.map { renderRichText($0) }.joined()
        let indentation = String(repeating: " ", count: level * 4)
        let checkbox = toDoBlock.checked ? "[x]" : "[ ]"
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer()
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        return indentation + "- \(checkbox) " + formattedText + "\n" + childrenText
    }

    private func renderToggle(_ block: Block) -> String {
        guard case let .toggle(toggleBlock) = block.blockTypeObject else { return "" }
        let formattedText = toggleBlock.text.map { renderRichText($0) }.joined()
        return "<details><summary>" + formattedText + "</summary>\n\n" +
               block.children.map { renderBlockToMarkdown($0) }.joined() +
               "</details>\n\n"
    }

    private func renderCode(_ block: Block) -> String {
        guard case let .code(codeBlock) = block.blockTypeObject else { return "" }
        let formattedText = codeBlock.text.map { renderRichText($0) }.joined()
        var captionText = codeBlock.caption.map { renderRichText($0) }.joined()
        if !captionText.isEmpty {
            captionText += "\n\n"
        }
        return "``` \(codeBlock.language)\n" + formattedText + "\n```\n\n" + captionText +
               block.children.map { renderBlockToMarkdown($0) }.joined()
    }

    private func renderQuote(_ block: Block) -> String {
        guard case let .quote(quoteBlock) = block.blockTypeObject else { return "" }
        let formattedText = quoteBlock.text.map { renderRichText($0) }.joined()
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer(level: 0)
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        if childrenText.isEmpty {
            return "> " + formattedText.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
        } else {
            let quotedText = (formattedText + "\n\n" + childrenText)
            let trimmed = quotedText.trimmingSuffixCharacters(in: CharacterSet(charactersIn: "\n"))
            let newlineCount = quotedText.count - trimmed.count
            let nearestTwoCount = (newlineCount + 1) / 2 * 2
            let newlines = String(repeating: "\n", count: nearestTwoCount)
            return "> " + trimmed.replacingOccurrences(of: "\n", with: "\n> ") + newlines
        }
    }

    // since markdown doesn't have a native callout style, use a quote style and insert the emoji on the first line
    private func renderCallout(_ block: Block) -> String {
        guard case let .callout(calloutBlock) = block.blockTypeObject else { return "" }
        let icon = calloutBlock.icon?.emoji ?? "ℹ️"
        let formattedText = calloutBlock.text.map { renderRichText($0) }.joined()
        var childrenText = ""
        if block.hasChildren {
            let renderer = childRenderer(level: 0)
            childrenText = block.children.map({
                renderer.renderBlockToMarkdown($0)
            }).joined(separator: "")
        }
        if childrenText.isEmpty {
            return "> " + icon + " " + formattedText.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
        } else {
            let quotedText = (icon + " " + formattedText + "\n\n" + childrenText)
            let trimmed = quotedText.trimmingSuffixCharacters(in: CharacterSet(charactersIn: "\n"))
            let newlineCount = quotedText.count - trimmed.count
            let nearestTwoCount = (newlineCount + 1) / 2 * 2
            let newlines = String(repeating: "\n", count: nearestTwoCount)
            return "> " + trimmed.replacingOccurrences(of: "\n", with: "\n> ") + newlines
        }
    }

    private func renderImage(_ block: Block) -> String {
        guard case let .image(imageBlock) = block.blockTypeObject else { return "" }
        let url = imageBlock.image.type.url
        let caption: String?
        if let text = imageBlock.image.caption {
            caption = try? self.render(text)
        } else {
            caption = nil
        }

        if let asset = downloadedAssets[url] {
            let name = URL(fileURLWithPath: asset.localPath).lastPathComponent
            return "![\(name)](assets/\(asset.localPath))\(caption.map({ "\n" + $0 }) ?? "")\n\n"
        }

        let name = URL(string: url)?.lastPathComponent ?? url
        return "![\(name)](\(url))\(caption.map({ "\n" + $0 }) ?? "")\n\n"
    }

    private func renderVideo(_ block: Block) -> String {
        guard case let .video(videoBlock) = block.blockTypeObject else { return "" }
        var caption = videoBlock.caption?.map { renderRichText($0) }.joined() ?? ""
        if !caption.isEmpty {
            caption += "\n\n"
        }

        let url = videoBlock.type.url
        if let asset = downloadedAssets[url] {
            let name = URL(string: url)?.lastPathComponent ?? url
            let fileExtension = URL(fileURLWithPath: asset.localPath).pathExtension.lowercased()

            // Common video file extensions
            let videoExtensions = ["mp4", "mov", "avi", "wmv", "m4v", "webm"]
            if videoExtensions.contains(fileExtension) {
                // Direct video file - link to local copy
                return "Video: [\(name)](assets/\(asset.localPath))\n\n" + caption
            } else {
                // Likely a webpage/thumbnail - show image and link to original
                return "![\(name)](assets/\(asset.localPath))\n[\(name)](\(url))\n\n" + caption
            }
        }

        let name = URL(string: url)?.lastPathComponent ?? url
        return "Video: [\(name)](\(url))\n\n" + caption
    }

    private func renderAudio(_ block: Block) -> String {
        guard case let .audio(audioBlock) = block.blockTypeObject else { return "" }
        var caption = audioBlock.caption?.map { renderRichText($0) }.joined() ?? ""
        if !caption.isEmpty {
            caption += "\n\n"
        }

        let url = audioBlock.type.url
        if let asset = downloadedAssets[url] {
            let name = URL(string: url)?.lastPathComponent ?? url

            return "Audio: [\(name)](assets/\(asset.localPath))\n\n" + caption
        }

        let name = URL(string: url)?.lastPathComponent ?? url
        return "Audio: [\(name)](\(url))\n\n" + caption
    }

    private func renderFile(_ block: Block) -> String {
        guard case let .file(fileBlock) = block.blockTypeObject else { return "" }
        var caption = fileBlock.caption?.map { renderRichText($0) }.joined() ?? ""
        if !caption.isEmpty {
            caption += "\n\n"
        }

        let url = fileBlock.type.url
        if let asset = downloadedAssets[url] {
            let name = URL(string: asset.localPath)?.lastPathComponent ?? asset.localPath
            return "File: [\(name)](assets/\(asset.localPath))\n\n" + caption
        }

        let name = URL(string: url)?.lastPathComponent ?? url
        return "File: [\(name)](\(url))\n\n" + caption
    }

    private func renderBookmark(_ block: Block) -> String {
        guard case let .bookmark(bookmarkBlock) = block.blockTypeObject else { return "" }
        var caption = bookmarkBlock.caption.map { renderRichText($0) }.joined()
        if !caption.isEmpty {
            caption += "\n\n"
        }
        return "[\(bookmarkBlock.url)](\(bookmarkBlock.url))\n\n" + caption
    }

    private func renderChildPage(_ block: Block) -> String {
        guard case let .childPage(childPage) = block.blockTypeObject else { return "" }
        return "[\(childPage.title)](\(block.id).md)\n\n"
    }

    private func renderTable(_ block: Block) -> String {
        guard case let .table(tableNode) = block.blockTypeObject else { return "" }
        let rowContents = block.children.compactMap({ child, row -> String? in
            guard case let .tableRow(tableRow) = child.blockTypeObject else { return nil }
            let foo = "<tr>" + tableRow.cells.map({ cell, column in
                let isColumnHeader = tableNode.hasColumnHeader && column == 0
                let isRowHeader = tableNode.hasRowHeader && row == 0
                let td = isColumnHeader || isRowHeader ? "<th>" : "<td>"
                let slashTD = isColumnHeader || isRowHeader ? "</th>" : "</td>"
                return td + cell.map { renderRichText($0) }.joined() + slashTD
            }).joined() + "</tr>\n"
            return foo
        })
        return "<table>\n" + rowContents.joined() + "</table>\n\n"
    }

    // TODO: Also fetch the linked child page, and lookup its title to render a rich link here
    private func renderLinkToPage(_ block: Block) -> String {
        guard case let .linkToPage(childPage) = block.blockTypeObject else { return "" }
        return "[\(childPage.pageId)](\(childPage.pageId).md)\n\n"
    }

    private func renderEmbed(_ block: Block) -> String {
        guard case let .embed(embed) = block.blockTypeObject else { return "" }
        return "Embed: [\(embed.url)](\(embed.url))\n\n"
    }

    private func renderLinkPreview(_ block: Block) -> String {
        guard case let .linkPreview(linkPreview) = block.blockTypeObject else { return "" }
        return "Preview: [\(linkPreview.url)](\(linkPreview.url))\n\n"
    }

    private func renderPDF(_ block: Block) -> String {
        guard case let .pdf(pdfBlock) = block.blockTypeObject else { return "" }
        let url = pdfBlock.pdf.type.url
        let caption: String?
        if let text = pdfBlock.pdf.caption {
            caption = try? self.render(text)
        } else {
            caption = nil
        }

        if let asset = downloadedAssets[url] {
            let name = URL(fileURLWithPath: asset.localPath).lastPathComponent
            return "PDF: [\(name)](assets/\(asset.localPath))\(caption.map({ "\n" + $0 }) ?? "")\n\n"
        }

        let name = URL(string: url)?.lastPathComponent ?? url
        return "PDF: [\(name)](\(url))\(caption.map({ "\n" + $0 }) ?? "")\n\n"
    }

    private func renderChildDatabase(_ block: Block) -> String {
        guard case let .childDatabase(database) = block.blockTypeObject else { return "" }
        return "Database: \(database.title)\n\n"
    }

    private func renderColumnList(_ block: Block) -> String {
        guard case .columnList = block.blockTypeObject else { return "" }
        // Start table with equal width columns
        let columnCount = block.children.count
        let width = 100 / columnCount
        let cells = block.children.map { child in
            "<td style=\"width: \(width)%;\">\n" +
            renderBlockToMarkdown(child).trimmingCharacters(in: .whitespacesAndNewlines) + "\n" +
            "</td>"
        }.joined()

        return "<table><tr>\n" + cells + "</tr></table>\n\n"
    }

    private func renderColumn(_ block: Block) -> String {
        guard case .column = block.blockTypeObject else { return "" }
        return block.children.map { renderBlockToMarkdown($0) }.joined()
    }

    private func renderSyncedBlock(_ block: Block) -> String {
        guard case .syncedBlock = block.blockTypeObject else { return "" }

        // For markdown export, just render the children directly
        // Whether it's an original or reference doesn't matter - we want the content
        if block.hasChildren {
            return block.children.map { renderBlockToMarkdown($0) }.joined()
        }
        return ""
    }

    // MARK: - Database Rendering

    private func renderDatabase(_ database: Database) -> String {
        let icon = database.icon?.emoji.map({ $0 + " " }) ?? ""
        let titleText = database.title.map { renderRichText($0) }.joined()
        let title = titleText.isEmpty ? "Untitled" : titleText
        var markdown = "# \(icon)\(title)\n\n"

        let propertyNames = database.properties.keys.sorted()
        if !propertyNames.isEmpty {
            markdown += "| Property | Type |\n"
            markdown += "| --- | --- |\n"
            for name in propertyNames {
                if let property = database.properties[name] {
                    markdown += "| \(name) | \(property.kind.rawValue) |\n"
                }
            }
            markdown += "\n"
        }

        return markdown
    }

    // MARK: - Page Rendering

    private func renderPage(_ page: Page) -> String {
        let icon = page.icon?.emoji.map({ $0 + " " }) ?? ""
        let titleText = page.title.map { renderRichText($0) }.joined()
        let title = titleText.isEmpty ? "Untitled" : titleText
        var markdown = "# \(icon)\(title)\n\n"

        let propertyNames = page.properties.keys.sorted()
        for name in propertyNames {
            guard let property = page.properties[name] else { continue }
            // Skip the title property since we already rendered it as the heading
            if property.kind == .title { continue }
            if let value = renderPropertyValue(property) {
                markdown += "- **\(name):** \(value)\n"
            }
        }

        if propertyNames.contains(where: { page.properties[$0]?.kind != .title }) {
            markdown += "\n"
        }

        return markdown
    }

    private func renderPropertyValue(_ property: Property) -> String? {
        switch property {
        case .title(_, let value):
            let text = value.map { renderRichText($0) }.joined()
            return text.isEmpty ? nil : text
        case .richText(_, let value):
            let text = value.map { renderRichText($0) }.joined()
            return text.isEmpty ? nil : text
        case .number(_, let value):
            return String(value)
        case .select(_, let value):
            return value.first?.name ?? ""
        case .multiSelect(_, let value):
            return value.map(\.name).joined(separator: ", ")
        case .date(_, let value):
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC")!
            var result = formatter.string(from: value.start)
            if let end = value.end {
                result += " - " + formatter.string(from: end)
            }
            return result
        case .people(_, let value):
            return value.compactMap(\.name).joined(separator: ", ")
        case .file(_, let value), .files(_, let value):
            return value.map(\.url).joined(separator: ", ")
        case .checkbox(_, let value):
            return value ? "Yes" : "No"
        case .url(_, let value):
            return "[\(value)](\(value))"
        case .email(_, let value):
            return value
        case .phoneNumber(_, let value):
            return value
        case .formula(_, let value):
            return value.type.stringValue
        case .relation(_, let value):
            return value.map(\.id).joined(separator: ", ")
        case .rollup(_, let value):
            return value.value
        case .createdTime(_, let value), .lastEditedTime(_, let value):
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = TimeZone(identifier: "UTC")!
            return formatter.string(from: value)
        case .createdBy(_, let value), .lastEditedBy(_, let value):
            return value.name ?? value.id
        case .status(_, let value):
            return value.name
        case .uniqueId(_, let value):
            if let prefix = value.prefix {
                return "\(prefix)-\(value.number)"
            }
            return String(value.number)
        case .null:
            return nil
        }
    }

    // MARK: - Comment Rendering

    private func renderComment(_ comment: Comment) -> String {
        let text = comment.richText.map { renderRichText($0) }.joined()
        return "> \(text)\n\n"
    }
}
