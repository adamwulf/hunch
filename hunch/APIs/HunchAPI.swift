//
//  HunchAPI.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation
import OSLog

class HunchAPI {
    public static var logHandler: ((_ level: OSLogType, _ message: String, _ context: [String: Any]?) -> Void)?
    public static let shared = HunchAPI(notion: NotionAPI.shared)

    public let notion: NotionAPI

    private init(notion: NotionAPI) {
        self.notion = notion
    }

    func fetchContents(of blockOrPageId: String) async -> [Block] {
        var blocks: [Block] = []
        var cursor: String?

        repeat {
            let result = await NotionAPI.shared.fetchBlockList(cursor: cursor, in: blockOrPageId)
            switch result {
            case .success(let fetchedBlocks):
                for var block in fetchedBlocks.results {
                    if block.hasChildren {
                        block.children = await fetchContents(of: block.id)
                    }
                    blocks.append(block)
                }
                cursor = fetchedBlocks.nextCursor
            case .failure(let error):
                fatalError("error: \(error.localizedDescription)")
            }
        } while cursor != nil

        return blocks
    }

    func fetchDatabases(parentId: String?, limit: Int = .max) async -> [Database] {
        var databases: [Database] = []
        var cursor: String?
        var count = 0

        repeat {
            let result = await notion.fetchDatabases(cursor: cursor, parentId: parentId)
            switch result {
            case .success(let dbs):
                for db in dbs.results {
                    databases.append(db)
                    count += 1
                    guard count < limit else { return databases }
                }
                cursor = dbs.nextCursor
            case .failure(let error):
                fatalError("error: \(error.localizedDescription)")
            }
        } while cursor != nil

        return databases
    }
}
