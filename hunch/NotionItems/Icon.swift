//
//  Icon.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

struct Icon: Codable {
    var type: String
    var emoji: String?
    var file: File?
    var external: External?

    struct File: Codable {
        var url: String
        var expiryTime: Date?

        enum CodingKeys: String, CodingKey {
            case url
            case expiryTime = "expiry_time"
        }
    }

    struct External: Codable {
        var url: String
    }
}
