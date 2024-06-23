//
//  NotionAPI.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//  From https://github.com/maeganwilson/NoitonSwift
//

import Foundation
import OSLog

class NotionAPI {
    public static var logHandler: ((_ level: OSLogType, _ message: String, _ context: [String: Any]?) -> Void)?
    public static let shared = NotionAPI()
    public var token: String?
    private init() {}

    private let urlSession = URLSession(configuration: .ephemeral)
    private let baseURL = URL(string: "https://api.notion.com/v1")!

    private let jsonDecoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var jsonDecorder = JSONDecoder()
        jsonDecorder.dateDecodingStrategy = .formatted(formatter)
        return jsonDecorder
    }()

    private let jsonEncoder: JSONEncoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .formatted(formatter)
        return jsonEncoder
    }()

    enum Endpoint: String, CaseIterable {
        case databases
        case pages
        case block
        case search
    }

    public enum NotionAPIServiceError: Error {
        case missingToken
        case apiError(_ error: Error)
        case invalidEndpoint
        case invalidResponse
        case invalidResponseStatus(_ status: Int)
        case noData
        case decodeError(_ error: Error)
        case encodeError(_ error: Error)
    }

    private func fetchResources<T: Decodable>(method: String = "GET",
                                              url: URL,
                                              body: Data? = nil,
                                              completion: @escaping (Result<T, NotionAPIServiceError>) -> Void) {
        guard let token = token else {
            completion(.failure(.missingToken))
            return
        }
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            completion(.failure(.invalidEndpoint))
            return
        }

        guard let url = urlComponents.url else {
            completion(.failure(.invalidEndpoint))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2021-05-13", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = method
        request.httpBody = body

        urlSession.dataTask(with: request) { (result) in
            switch result {
            case .success(let (response, data)):
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                guard 200..<299 ~= httpResponse.statusCode else {
                    completion(.failure(.invalidResponseStatus(httpResponse.statusCode)))
                    return
                }
                Self.logHandler?(.debug, "notion_api", ["status": httpResponse.statusCode])
                Self.logHandler?(.debug, String(data: data, encoding: .utf8)!, nil)
                do {
                    let values = try self.jsonDecoder.decode(T.self, from: data)
                    completion(.success(values))
                } catch {
                    completion(.failure(.decodeError(error)))
                }
            case .failure(let error):
                completion(.failure(.apiError(error)))
            }
        }.resume()
    }

    func fetchDatabases() async -> Result<DatabaseList, NotionAPIServiceError> {
        return await withCheckedContinuation { continuation in
            fetchResources(url: baseURL.appendingPathComponent("databases"), completion: { result in
                continuation.resume(returning: result)
            })
        }
    }

    private func fetchDatabases(completion: @escaping (Result<DatabaseList, NotionAPIServiceError>) -> Void) {
        fetchResources(url: baseURL.appendingPathComponent("databases"), completion: completion)
    }

    func fetchDatabaseEntries(in database: Database, completion: @escaping (Result<PageList, NotionAPIServiceError>) -> Void) {
        let url = baseURL.appendingPathComponent("databases").appendingPathComponent(database.id).appendingPathComponent("query")
        fetchResources(method: "POST", url: url, body: nil, completion: completion)
    }

    func fetchPageContent(in page: Page, completion: @escaping (Result<BlockList, NotionAPIServiceError>) -> Void) {
        let url = baseURL.appendingPathComponent("blocks").appendingPathComponent(page.id).appendingPathComponent("children")
        fetchResources(method: "GET", url: url, body: nil, completion: completion)
    }

    func fetchPages(completion: @escaping (Result<PageList, NotionAPIServiceError>) -> Void) {
        let bodyJSON: [String: Any] = [:]
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: bodyJSON, options: [])
            fetchResources(method: "POST", url: baseURL.appendingPathComponent("search"), body: bodyData, completion: completion)
        } catch {
            completion(.failure(.encodeError(error)))
        }
    }
}
