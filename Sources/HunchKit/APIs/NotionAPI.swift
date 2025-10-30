//
//  NotionAPI.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//  From https://github.com/maeganwilson/NoitonSwift
//

import Foundation
import OSLog

public class NotionAPI {
    public static var logHandler: ((_ level: OSLogType, _ message: String, _ context: [String: Any]?) -> Void)?
    public static let shared = NotionAPI()
    public var token: String?
    private init() {}

    private let urlSession = URLSession(configuration: .ephemeral)
    private let baseURL = URL(string: "https://api.notion.com/v1")!

    private let maxRetries = 3
    private let minRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 60.0

    let jsonDecoder: JSONDecoder = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var jsonDecorder = JSONDecoder()
        jsonDecorder.dateDecodingStrategy = .formatted(formatter)
        return jsonDecorder
    }()

    let jsonEncoder: JSONEncoder = {
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

    public enum NotionAPIServiceError: Error, LocalizedError {
        case missingToken
        case apiError(_ error: Error)
        case invalidEndpoint
        case invalidResponse
        case invalidResponseStatus(_ status: Int)
        case noData
        case decodeError(_ error: Error)
        case encodeError(_ error: Error)
        case rateLimitExceeded(retryAfter: TimeInterval)

        var localizedDescription: String {
            switch self {
            case .missingToken:
                return "missing token"
            case .apiError(let error):
                return "api error: \(error.localizedDescription)"
            case .invalidEndpoint:
                return "invalid endpoint"
            case .invalidResponse:
                return "invalid response"
            case .invalidResponseStatus(let statusCode):
                return "invalid response status: \(statusCode)"
            case .noData:
                return "no data"
            case .decodeError(let error):
                return "decode error: \(error.localizedDescription)"
            case .encodeError(let error):
                return "encode error: \(error.localizedDescription)"
            case .rateLimitExceeded(let retryAfter):
                return "Rate limit exceeded. Retry after \(retryAfter) seconds"
            }
        }
    }

    private func fetchResources<T: Decodable>(
        method: String = "GET",
        url: URL,
        query: [String: String] = [:],
        body: Data? = nil,
        retryCount: Int = 0,
        completion: @escaping (Result<T, NotionAPIServiceError>) -> Void
    ) {
        guard let token = token else {
            completion(.failure(.missingToken))
            return
        }
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            completion(.failure(.invalidEndpoint))
            return
        }

        urlComponents.queryItems = query.map({ URLQueryItem(name: $0.key, value: $0.value) })

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

        urlSession.dataTask(with: request) { [weak self] (result) in
            guard let self = self else { return }

            switch result {
            case .success(let (response, data)):
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }

                if httpResponse.statusCode == 429 || (500...599).contains(httpResponse.statusCode) {
                    let retryAfter = TimeInterval(httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "5") ?? 5

                    if retryCount < self.maxRetries {
                        let backoffDelay = min(
                            self.maxRetryDelay,
                            self.minRetryDelay * pow(2.0, Double(retryCount))
                        )
                        let delayInterval = 1 + max(retryAfter, backoffDelay)

                        Self.logHandler?(.error, "\(httpResponse.statusCode) error, retrying after \(delayInterval) seconds",
                            ["attempt": retryCount + 1,
                             "max_attempts": self.maxRetries,
                             "status": httpResponse.statusCode,
                             "path": url.path(percentEncoded: false)])

                        DispatchQueue.global().asyncAfter(deadline: .now() + delayInterval) {
                            self.fetchResources(
                                method: method,
                                url: url,
                                query: query,
                                body: body,
                                retryCount: retryCount + 1,
                                completion: completion
                            )
                        }
                        return
                    }
                }

                guard 200..<299 ~= httpResponse.statusCode else {
                    Self.logHandler?(.error, "Notion API error", [
                        "status": httpResponse.statusCode,
                        "path": url.path(percentEncoded: false)
                    ])
                    completion(.failure(.invalidResponseStatus(httpResponse.statusCode)))
                    return
                }

                Self.logHandler?(.debug, "notion_api", ["status": httpResponse.statusCode, "path": url.path(percentEncoded: false)])
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

    internal func fetchDatabases(cursor: String?, parentId: String?) async -> Result<DatabaseList, NotionAPIServiceError> {
        return await withCheckedContinuation { continuation in
            fetchResources(url: baseURL.appendingPathComponent("databases"),
                           query: ["start_cursor": cursor, "parent": parentId].compactMapValues({ $0 }),
                           completion: { result in
                continuation.resume(returning: result)
            })
        }
    }

    internal func fetchPages(cursor: String?, databaseId: String?) async -> Result<PageList, NotionAPIServiceError> {
        return await withCheckedContinuation { continuation in
            let bodyJSON: [String: Any] = ["start_cursor": cursor].compactMapValues({ $0 })
            do {
                if let databaseId = databaseId {
                    let bodyData = try JSONSerialization.data(withJSONObject: bodyJSON, options: [])
                    let targetURL = baseURL.appendingPathComponent("databases")
                        .appendingPathComponent(databaseId)
                        .appendingPathComponent("query")
                    fetchResources(method: "POST",
                                   url: targetURL,
                                   query: [:],
                                   body: bodyData) { result in
                        continuation.resume(returning: result)
                    }
                } else {
                    let bodyData = try JSONSerialization.data(withJSONObject: bodyJSON, options: [])
                    fetchResources(method: "POST",
                                   url: baseURL.appendingPathComponent("search"),
                                   query: ["start_cursor": cursor].compactMapValues({ $0 }),
                                   body: bodyData) { result in
                        continuation.resume(returning: result)
                    }
                }
            } catch {
                continuation.resume(returning: .failure(.encodeError(error)))
            }
        }
    }

    internal func retrievePage(pageId: String) async -> Result<Page, NotionAPIServiceError> {
        return await withCheckedContinuation { continuation in
            let url = baseURL.appendingPathComponent("pages").appendingPathComponent(pageId)
            fetchResources(method: "GET",
                           url: url,
                           query: [:],
                           body: nil) { result in
                continuation.resume(returning: result)
            }
        }
    }

    internal func fetchBlockList(cursor: String?, in pageOrBlockId: String) async -> Result<BlockList, NotionAPIServiceError> {
        return await withCheckedContinuation { continuation in
            let url = baseURL.appendingPathComponent("blocks").appendingPathComponent(pageOrBlockId).appendingPathComponent("children")
            fetchResources(method: "GET",
                           url: url,
                           query: ["start_cursor": cursor].compactMapValues({ $0 }),
                           body: nil) { result in
                continuation.resume(returning: result)
            }
        }
    }
}
