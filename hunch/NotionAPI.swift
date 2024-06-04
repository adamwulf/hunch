//
//  NotionAPI.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//  From https://github.com/maeganwilson/NoitonSwift
//

import Foundation

class NotionAPI {
    enum LogLevel {
        case verbose
        case debug
        case info
        case warning
        case error
    }

    public static var logHandler: ((_ level: LogLevel, _ message: String, _ context: [String: Any]) -> Void)?
    public static let shared = NotionAPI()
    public var token: String? = nil
    private init(){}

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
        case noData
        case decodeError(_ error: Error)
        case encodeError
    }

    private func fetchResources<T: Decodable>(method: String = "GET",
                                              url: URL,
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
        request.httpMethod = method

        urlSession.dataTask(with: request){ (result) in
            switch result {
            case .success(let (response, data)):
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, 200..<299 ~= statusCode else {
                    completion(.failure(.invalidResponse))
                    return
                }
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

    func fetchDatabases(completion: @escaping (Result<DatabaseList, NotionAPIServiceError>) -> Void) {
        fetchResources(url: baseURL.appendingPathComponent("databases"), completion: completion)
    }

    func fetchPages(completion: @escaping (Result<PageList, NotionAPIServiceError>) -> Void) {
        fetchResources(method: "POST", url: baseURL.appendingPathComponent("search"), completion: completion)
    }
}
