//
//  Model.swift
//  hunch
//
//  Created by Adam Wulf on 5/19/21.
//  From https://github.com/maeganwilson/NoitonSwift
//

import Foundation

enum Property: Codable {
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
    }

    enum Kind: String, Codable {
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
        case null
    }

    var kind: Kind {
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
        case .null: .null
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let kind = try container.decode(Kind.self, forKey: .type)

        do {
            switch kind {
            case .title:
                let value = try container.decode([RichText].self, forKey: .title)
                self = .title(id: id, value: value)
            case .richText:
                let value = try container.decode([RichText].self, forKey: .richText)
                self = .richText(id: id, value: value)
            case .number:
                let value = try container.decode(Double.self, forKey: .number)
                self = .number(id: id, value: value)
            case .select:
                let value = try container.decode(SelectOption.self, forKey: .select)
                self = .select(id: id, value: value)
            case .multiSelect:
                let value = try container.decode([String: [SelectOption]].self, forKey: .multiSelect)
                self = .multiSelect(id: id, value: value["options"] ?? [])
            case .date:
                let value = try container.decode(DateRange.self, forKey: .date)
                self = .date(id: id, value: value)
            case .people:
                let value = try container.decode([User].self, forKey: .people)
                self = .people(id: id, value: value)
            case .file:
                let value = try container.decode([File].self, forKey: .file)
                self = .file(id: id, value: value)
            case .files:
                let value = try container.decode([File].self, forKey: .files)
                self = .files(id: id, value: value)
            case .checkbox:
                let value = try container.decode(Bool.self, forKey: .checkbox)
                self = .checkbox(id: id, value: value)
            case .url:
                let value = try container.decode(String.self, forKey: .url)
                self = .url(id: id, value: value)
            case .email:
                let value = try container.decode(String.self, forKey: .email)
                self = .email(id: id, value: value)
            case .phoneNumber:
                let value = try container.decode(String.self, forKey: .phoneNumber)
                self = .phoneNumber(id: id, value: value)
            case .formula:
                let value = try container.decode(Formula.self, forKey: .formula)
                self = .formula(id: id, value: value)
            case .relation:
                let value = try container.decode([Relation].self, forKey: .relation)
                self = .relation(id: id, value: value)
            case .rollup:
                let value = try container.decode(Rollup.self, forKey: .rollup)
                self = .rollup(id: id, value: value)
            case .createdTime:
                let value = try container.decode(Date.self, forKey: .createdTime)
                self = .createdTime(id: id, value: value)
            case .createdBy:
                let value = try container.decode(User.self, forKey: .createdBy)
                self = .createdBy(id: id, value: value)
            case .lastEditedTime:
                let value = try container.decode(Date.self, forKey: .lastEditedTime)
                self = .lastEditedTime(id: id, value: value)
            case .lastEditedBy:
                let value = try container.decode(User.self, forKey: .lastEditedBy)
                self = .lastEditedBy(id: id, value: value)
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .null:
            break
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
            try container.encode(["options": value], forKey: .multiSelect)
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
        }
    }
}

struct SelectOption: Codable {
    var name: String
}

struct DateRange: Codable {
    var start: Date
    var end: Date?
}

struct File: Codable {
    var url: String
    var expiryTime: Date?

    enum CodingKeys: String, CodingKey {
        case url
        case expiryTime = "expiry_time"
    }
}

struct Formula: Codable {
    var expression: String
}

struct Relation: Codable {
    var id: String
}

struct Rollup: Codable {
    var value: String
}
