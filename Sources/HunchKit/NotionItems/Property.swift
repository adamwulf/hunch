//
//  Model.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//  From https://github.com/maeganwilson/NoitonSwift
//

import Foundation

public enum Property: Codable {
    case title(id: String, value: [RichText])
    case richText(id: String, value: [RichText])
    case number(id: String, value: Double)
    case select(id: String, value: SelectOption)
    case multiSelect(id: String, value: [SelectOption])
    case date(id: String, value: DateRange)
    case people(id: String, value: [User])
    case file(id: String, value: [File])
    case files(id: String, value: [File])
    case checkbox(id: String, value: Bool)
    case url(id: String, value: String)
    case email(id: String, value: String)
    case phoneNumber(id: String, value: String)
    case formula(id: String, value: Formula)
    case relation(id: String, value: [Relation])
    case rollup(id: String, value: Rollup)
    case createdTime(id: String, value: Date)
    case createdBy(id: String, value: User)
    case lastEditedTime(id: String, value: Date)
    case lastEditedBy(id: String, value: User)
    case status(id: String, value: StatusOption)
    case uniqueId(id: String, value: UniqueId)
    case null(id: String, type: Kind)

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case value
        case title
        case richText = "rich_text"
        case number
        case select
        case multiSelect = "multi_select"
        case date
        case people
        case file
        case files
        case checkbox
        case url
        case email
        case phoneNumber = "phone_number"
        case formula
        case relation
        case rollup
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
        case status
        case uniqueId = "unique_id"
    }

    public enum Kind: String, Codable {
        case title
        case richText = "rich_text"
        case number
        case select
        case multiSelect = "multi_select"
        case date
        case people
        case file
        case files
        case checkbox
        case url
        case email
        case phoneNumber = "phone_number"
        case formula
        case relation
        case rollup
        case createdTime = "created_time"
        case createdBy = "created_by"
        case lastEditedTime = "last_edited_time"
        case lastEditedBy = "last_edited_by"
        case status
        case uniqueId = "unique_id"
        case null
    }

    public var kind: Kind {
        switch self {
        case .title: .title
        case .richText: .richText
        case .number: .number
        case .select: .select
        case .multiSelect: .multiSelect
        case .date: .date
        case .people: .people
        case .file: .file
        case .files: .files
        case .checkbox: .checkbox
        case .url: .url
        case .email: .email
        case .phoneNumber: .phoneNumber
        case .formula: .formula
        case .relation: .relation
        case .rollup: .rollup
        case .createdTime: .createdTime
        case .createdBy: .createdBy
        case .lastEditedTime: .lastEditedTime
        case .lastEditedBy: .lastEditedBy
        case .status: .status
        case .uniqueId: .uniqueId
        case .null: .null
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let kind = try container.decode(Kind.self, forKey: .type)

        do {
            switch kind {
            case .title:
                // Notion API returns [] for page values, {} for database schema definitions
                if let value = try? container.decode([RichText].self, forKey: .title) {
                    self = .title(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .richText:
                // Notion API returns [] for page values, {} for database schema definitions
                if let value = try? container.decode([RichText].self, forKey: .richText) {
                    self = .richText(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .number:
                if let value = try? container.decodeIfPresent(Double.self, forKey: .number) {
                    self = .number(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .select:
                if let value = try? container.decodeIfPresent(SelectOption.self, forKey: .select) {
                    self = .select(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .multiSelect:
                do {
                    let value = try container.decode([SelectOption].self, forKey: .multiSelect)
                    self = .multiSelect(id: id, value: value)
                } catch {
                    if let value = try? container.decode(MultiSelect.self, forKey: .multiSelect) {
                        self = .multiSelect(id: id, value: value.options)
                    } else {
                        self = .null(id: id, type: kind)
                    }
                }
            case .date:
                if let value = try? container.decodeIfPresent(DateRange.self, forKey: .date) {
                    self = .date(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .people:
                if let value = try? container.decode([User].self, forKey: .people) {
                    self = .people(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .file:
                // Notion API returns [] for page values, {} for database schema definitions
                if let value = try? container.decode([File].self, forKey: .file) {
                    self = .file(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .files:
                // Notion API returns [] for page values, {} for database schema definitions
                if let value = try? container.decode([File].self, forKey: .files) {
                    self = .files(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .checkbox:
                if let value = try? container.decode(Bool.self, forKey: .checkbox) {
                    self = .checkbox(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .url:
                if let value = try? container.decodeIfPresent(String.self, forKey: .url) {
                    self = .url(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .email:
                if let value = try? container.decodeIfPresent(String.self, forKey: .email) {
                    self = .email(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .phoneNumber:
                if let value = try? container.decodeIfPresent(String.self, forKey: .phoneNumber) {
                    self = .phoneNumber(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .formula:
                if let value = try? Formula(from: decoder) {
                    self = .formula(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .relation:
                if let value = try? container.decode([Relation].self, forKey: .relation) {
                    self = .relation(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .rollup:
                if let value = try? container.decode(Rollup.self, forKey: .rollup) {
                    self = .rollup(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .createdTime:
                if let value = try? container.decode(Date.self, forKey: .createdTime) {
                    self = .createdTime(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .createdBy:
                if let value = try? container.decode(User.self, forKey: .createdBy) {
                    self = .createdBy(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .lastEditedTime:
                if let value = try? container.decode(Date.self, forKey: .lastEditedTime) {
                    self = .lastEditedTime(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .lastEditedBy:
                if let value = try? container.decode(User.self, forKey: .lastEditedBy) {
                    self = .lastEditedBy(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .status:
                if let value = try? container.decodeIfPresent(StatusOption.self, forKey: .status) {
                    self = .status(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .uniqueId:
                if let value = try? container.decode(UniqueId.self, forKey: .uniqueId) {
                    self = .uniqueId(id: id, value: value)
                } else {
                    self = .null(id: id, type: kind)
                }
            case .null:
                self = .null(id: id, type: kind)
            }
        } catch {
            let path = decoder.codingPath.map({ $0.intValue.map({ "\($0)" }) ?? $0.stringValue }).joined(separator: ",")
            NotionAPI.logHandler?(.error, "notion_api", ["status": "decoding_error",
                                                         "error": error.localizedDescription,
                                                         "path": path,
                                                         "key": kind.rawValue])
            self = .null(id: id, type: kind)
        }

    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .null(let id, let type):
            try container.encode(id, forKey: .id)
            try container.encode(type, forKey: .type)
        case .title(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.title, forKey: .type)
            try container.encode(value, forKey: .value)
        case .richText(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.richText, forKey: .type)
            try container.encode(value, forKey: .value)
        case .number(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.number, forKey: .type)
            try container.encode(value, forKey: .value)
        case .select(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.select, forKey: .type)
            try container.encode(value, forKey: .value)
        case .multiSelect(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.multiSelect, forKey: .type)
            try container.encode(value, forKey: .multiSelect)
        case .date(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.date, forKey: .type)
            try container.encode(value, forKey: .value)
        case .people(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.people, forKey: .type)
            try container.encode(value, forKey: .value)
        case .file(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.file, forKey: .type)
            try container.encode(value, forKey: .value)
        case .files(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.files, forKey: .type)
            try container.encode(value, forKey: .value)
        case .checkbox(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.checkbox, forKey: .type)
            try container.encode(value, forKey: .value)
        case .url(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.url, forKey: .type)
            try container.encode(value, forKey: .value)
        case .email(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.email, forKey: .type)
            try container.encode(value, forKey: .value)
        case .phoneNumber(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.phoneNumber, forKey: .type)
            try container.encode(value, forKey: .value)
        case .formula(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.formula, forKey: .type)
            try container.encode(value, forKey: .value)
        case .relation(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.relation, forKey: .type)
            try container.encode(value, forKey: .value)
        case .rollup(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.rollup, forKey: .type)
            try container.encode(value, forKey: .value)
        case .createdTime(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.createdTime, forKey: .type)
            try container.encode(value, forKey: .value)
        case .createdBy(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.createdBy, forKey: .type)
            try container.encode(value, forKey: .value)
        case .lastEditedTime(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.lastEditedTime, forKey: .type)
            try container.encode(value, forKey: .value)
        case .lastEditedBy(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.lastEditedBy, forKey: .type)
            try container.encode(value, forKey: .value)
        case .status(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.status, forKey: .type)
            try container.encode(value, forKey: .status)
        case .uniqueId(let id, let value):
            try container.encode(id, forKey: .id)
            try container.encode(Kind.uniqueId, forKey: .type)
            try container.encode(value, forKey: .uniqueId)
        }
    }
}

public struct SelectOption: Codable {
    public internal(set) var id: String
    public internal(set) var name: String
    public internal(set) var color: Color
}

public struct DateRange: Codable {
    public internal(set) var start: Date
    public internal(set) var end: Date?
}

public struct File: Codable {
    public internal(set) var url: String
    public internal(set) var expiryTime: Date?

    enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

public struct Formula: Codable {
    public let type: FormulaType

    public enum FormulaType {
        case boolean(Bool?)
        case date(Date?)
        case number(Double?)
        case string(String?)

        public var value: Any? {
            switch self {
            case .boolean(let bool): bool
            case .date(let date): date
            case .number(let number): number
            case .string(let string): string
            }
        }

        public var stringValue: String? {
            switch self {
            case .boolean(let bool): bool.map { String($0) }
            case .date(let date): date.map {
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(identifier: "UTC")!
                return formatter.string(from: $0)
            }
            case .number(let number): number.map { String($0) }
            case .string(let string): string
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case formula
        case type
        case boolean
        case date
        case number
        case string
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let formulaContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .formula)
        let type = try formulaContainer.decode(String.self, forKey: .type)

        switch type {
        case "boolean":
            let value = try formulaContainer.decodeIfPresent(Bool.self, forKey: .boolean)
            self.type = .boolean(value)
        case "date":
            let value = try formulaContainer.decodeIfPresent(Date.self, forKey: .date)
            self.type = .date(value)
        case "number":
            let value = try formulaContainer.decodeIfPresent(Double.self, forKey: .number)
            self.type = .number(value)
        case "string":
            let value = try formulaContainer.decodeIfPresent(String.self, forKey: .string)
            self.type = .string(value)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: formulaContainer, debugDescription: "Unknown formula type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var formulaContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .formula)

        switch type {
        case .boolean(let value):
            try formulaContainer.encode("boolean", forKey: .type)
            try formulaContainer.encode(value, forKey: .boolean)
        case .date(let value):
            try formulaContainer.encode("date", forKey: .type)
            try formulaContainer.encode(value, forKey: .date)
        case .number(let value):
            try formulaContainer.encode("number", forKey: .type)
            try formulaContainer.encode(value, forKey: .number)
        case .string(let value):
            try formulaContainer.encode("string", forKey: .type)
            try formulaContainer.encode(value, forKey: .string)
        }
    }
}

public struct Relation: Codable {
    public internal(set) var id: String
}

public struct Rollup: Codable {
    public internal(set) var value: String
}

public struct StatusOption: Codable {
    public internal(set) var id: String?
    public internal(set) var name: String
    public internal(set) var color: Color?
}

public struct UniqueId: Codable {
    public internal(set) var number: Int
    public internal(set) var prefix: String?
}

// This property is specific to the multi-select definition in a database
private struct MultiSelect: Codable {
    public internal(set) var options: [SelectOption]
}
