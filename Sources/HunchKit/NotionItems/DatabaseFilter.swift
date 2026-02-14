//
//  DatabaseFilter.swift
//  hunch
//
//  Created by Adam Wulf on 2/13/26.
//

import Foundation

/// A flexible Codable wrapper for Notion database filter JSON.
/// Preserves arbitrary nested filter structures for pass-through encoding/decoding.
public struct DatabaseFilter: Codable {
    private let value: JSONValue

    public init(from decoder: Decoder) throws {
        value = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

/// A generic JSON value type for preserving arbitrary JSON structures.
public indirect enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode JSON value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

public struct DatabaseSort: Codable {
    public let property: String?
    public let timestamp: TimestampSort?
    public let direction: Direction

    public enum Direction: String, Codable {
        case ascending
        case descending
    }

    public enum TimestampSort: String, Codable {
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }

    public init(property: String, direction: Direction) {
        self.property = property
        self.timestamp = nil
        self.direction = direction
    }

    public init(timestamp: TimestampSort, direction: Direction) {
        self.property = nil
        self.timestamp = timestamp
        self.direction = direction
    }
}
