//
//  HunchAPI.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation
import OSLog

public enum HunchAPIError: LocalizedError {
    case apiError(NotionAPI.NotionAPIServiceError)

    public var errorDescription: String? {
        switch self {
        case .apiError(let error):
            return error.localizedDescription
        }
    }
}

public class HunchAPI {
    public static var logHandler: ((_ level: OSLogType, _ message: String, _ context: [String: Any]?) -> Void)?
    public static let shared = HunchAPI(notion: NotionAPI.shared)

    public let notion: NotionAPI

    private init(notion: NotionAPI) {
        self.notion = notion
    }

    public func fetchDatabases(parentId: String?, limit: Int = .max) async throws -> [Database] {
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
                throw HunchAPIError.apiError(error)
            }
        } while cursor != nil

        return databases
    }

    public func retrieveDatabase(databaseId: String) async throws -> Database {
        let result = await notion.retrieveDatabase(databaseId: databaseId)
        switch result {
        case .success(let database):
            return database
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    public func fetchPages(databaseId: String?, limit: Int = .max, filter: DatabaseFilter? = nil, sorts: [DatabaseSort]? = nil) async throws -> [Page] {
        var pages: [Page] = []
        var cursor: String?
        var count = 0

        repeat {
            let result = await notion.fetchPages(cursor: cursor, databaseId: databaseId, filter: filter, sorts: sorts)
            switch result {
            case .success(let pageList):
                for page in pageList.results {
                    pages.append(page)
                    count += 1
                    guard count < limit else { return pages }
                }
                cursor = pageList.nextCursor
            case .failure(let error):
                throw HunchAPIError.apiError(error)
            }
        } while cursor != nil

        return pages
    }

    public func retrievePage(pageId: String) async throws -> Page {
        let result = await notion.retrievePage(pageId: pageId)
        switch result {
        case .success(let page):
            return page
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    public func fetchBlocks(in blockOrPageId: String) async throws -> [Block] {
        var blocks: [Block] = []
        var cursor: String?

        repeat {
            let result = await NotionAPI.shared.fetchBlockList(cursor: cursor, in: blockOrPageId)
            switch result {
            case .success(let fetchedBlocks):
                for var block in fetchedBlocks.results {
                    if block.hasChildren {
                        block.children = try await fetchBlocks(in: block.id)
                    }
                    blocks.append(block)
                }
                cursor = fetchedBlocks.nextCursor
            case .failure(let error):
                throw HunchAPIError.apiError(error)
            }
        } while cursor != nil

        return blocks
    }

    // MARK: - Update Page

    public func updatePage(pageId: String, properties: JSONValue? = nil, archived: Bool? = nil) async throws -> Page {
        let result = await notion.updatePage(pageId: pageId, properties: properties, archived: archived)
        switch result {
        case .success(let page):
            return page
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    // MARK: - Create Page

    public func createPage(parentDatabaseId: String, properties: JSONValue, children: [JSONValue]? = nil) async throws -> Page {
        let result = await notion.createPage(parentDatabaseId: parentDatabaseId, properties: properties, children: children)
        switch result {
        case .success(let page):
            return page
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    // MARK: - Block Operations

    public func appendBlockChildren(blockId: String, children: Data) async throws -> [Block] {
        let result = await notion.appendBlockChildren(blockId: blockId, children: children)
        switch result {
        case .success(let blockList):
            return blockList.results
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    public func updateBlock(blockId: String, body: Data) async throws -> Block {
        let result = await notion.updateBlock(blockId: blockId, body: body)
        switch result {
        case .success(let block):
            return block
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    public func deleteBlock(blockId: String) async throws -> Block {
        let result = await notion.deleteBlock(blockId: blockId)
        switch result {
        case .success(let block):
            return block
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    // MARK: - Comments

    public func fetchComments(blockId: String) async throws -> [Comment] {
        var comments: [Comment] = []
        var cursor: String?

        repeat {
            let result = await notion.fetchComments(blockId: blockId, cursor: cursor)
            switch result {
            case .success(let commentList):
                comments.append(contentsOf: commentList.results)
                cursor = commentList.nextCursor
            case .failure(let error):
                throw HunchAPIError.apiError(error)
            }
        } while cursor != nil

        return comments
    }

    public func createComment(body: Data) async throws -> Comment {
        let result = await notion.createComment(body: body)
        switch result {
        case .success(let comment):
            return comment
        case .failure(let error):
            throw HunchAPIError.apiError(error)
        }
    }

    // MARK: - Search

    public func search(query: String? = nil, filter: SearchFilter? = nil, sort: SearchSort? = nil, limit: Int = .max) async throws -> [NotionItem] {
        var items: [NotionItem] = []
        var cursor: String?
        var count = 0

        repeat {
            let result = await notion.search(query: query, filter: filter, sort: sort, cursor: cursor)
            switch result {
            case .success(let searchResults):
                for item in searchResults.results {
                    items.append(item.asNotionItem)
                    count += 1
                    guard count < limit else { return items }
                }
                cursor = searchResults.nextCursor
            case .failure(let error):
                throw HunchAPIError.apiError(error)
            }
        } while cursor != nil

        return items
    }
}
