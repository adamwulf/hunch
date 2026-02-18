//
//  UsersCommand.swift
//  hunch
//
//  Created by Adam Wulf on 2/17/26.
//

import Foundation
import ArgumentParser
import HunchKit

struct UsersCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "users",
        abstract: "List users in the Notion workspace"
    )

    @Option(name: .shortAndLong, help: "The Notion user ID to retrieve a single user")
    var id: String?

    @Option(name: .shortAndLong, help: "The maximum number of results to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "The format of the output")
    var format: Hunch.Format = .id

    func run() async {
        do {
            if let userId = id {
                let user = try await HunchAPI.shared.retrieveUser(userId: userId)
                Hunch.output(list: [user], format: format)
            } else {
                let limit = limit ?? .max
                let users = try await HunchAPI.shared.fetchUsers(limit: limit)
                Hunch.output(list: users, format: format)
            }
        } catch {
            fatalError("error: \(error.localizedDescription)")
        }
    }
}
