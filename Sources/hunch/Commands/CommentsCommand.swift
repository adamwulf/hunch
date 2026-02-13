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

    func run() async {
        do {
            if let commentText = add {
                let body = buildCommentBody(text: commentText)
                let comment = try await HunchAPI.shared.createComment(body: body)
                printComment(comment)
            } else {
                let comments = try await HunchAPI.shared.fetchComments(blockId: blockId)
                for comment in comments {
                    printComment(comment)
                }
            }
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }

    private func buildCommentBody(text: String) -> Data {
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

        // swiftlint:disable:next force_try
        return try! JSONSerialization.data(withJSONObject: body, options: [])
    }

    private func printComment(_ comment: Comment) {
        let text = comment.richText.map({ $0.plainText }).joined()
        print("\(comment.id) [\(comment.createdTime)] \(text)")
    }
}
