//
//  NotionEncoder.swift
//  hunch
//
//  Created by Adam Wulf on 9/1/24.
//

import Foundation

extension NotionItem {
    func asJSON() throws -> Data {
        return try NotionEncoder().encode(self)
    }
}

class NotionEncoder: JSONEncoder {
    override func encode<T>(_ value: T) throws -> Data where T: Encodable {
        if let item = value as? NotionItem {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = self.dateEncodingStrategy
            encoder.keyEncodingStrategy = self.keyEncodingStrategy
            encoder.outputFormatting = self.outputFormatting

            return try encoder.encode(NotionItemWrapper(item))
        } else {
            return try super.encode(value)
        }
    }
}

struct NotionItemWrapper: Encodable {
    let item: NotionItem

    init(_ item: NotionItem) {
        self.item = item
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)

        // Encode the original item
        try item.encode(to: container.superEncoder())

        // Add the description
        try container.encode(item.description, forKey: .init("description"))
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(_ string: String) {
            stringValue = string
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }
}
