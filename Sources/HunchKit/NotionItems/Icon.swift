//
//  Icon.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

public struct Icon: Codable {
    public internal(set) var type: String
    public internal(set) var emoji: String?
    public internal(set) var file: File?
    public internal(set) var external: External?

    public struct File: Codable {
        public internal(set) var url: String
        public internal(set) var expiryTime: Date?

        enum CodingKeys: String, CodingKey {
            case url
            case expiryTime = "expiry_time"
        }
    }

    public struct External: Codable {
        public internal(set) var url: String
    }
}
