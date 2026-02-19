//
//  CommentsCommand.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation
import ArgumentParser
import HunchKit

struct CommentsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "comments",
        abstract: "List or add comments on a page or block"
    )

    @Argument(help: "The Notion page or block ID")
    var blockId: String

    @Option(name: .shortAndLong, help: "Add a comment with this text content")
    var add: String?

    @Option(name: .long, help: "Discussion ID for threaded replies")
    var discussionId: String?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async throws {
        if let commentText = add {
            let body = try buildCommentBody(text: commentText)
            let comment = try await HunchAPI.shared.createComment(body: body)
            Hunch.output(list: [comment], format: format)
        } else {
            let comments = try await HunchAPI.shared.fetchComments(blockId: blockId)
            Hunch.output(list: comments, format: format)
        }
    }

    private func buildCommentBody(text: String) throws -> Data {
        var body: [String: Any] = [
            "rich_text": [
                [
                    "type": "text",
                    "text": ["content": text]
                ]
            ]
        ]

        if let discussionId = discussionId {
            body["discussion_id"] = discussionId
        } else {
            body["parent"] = ["page_id": blockId]
        }

        return try JSONSerialization.data(withJSONObject: body, options: [])
    }
}
