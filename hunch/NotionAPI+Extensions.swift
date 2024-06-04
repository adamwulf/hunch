//
//  NotionAPI+Extensions.swift
//  hunch
//
//  Created by Adam Wulf on 6/4/24.
//

import Foundation

extension NotionAPI.LogLevel {
    var stringValue: String {
        switch self {
        case .verbose: "verbose"
        case .debug: "debug"
        case .info: "info"
        case .warning: "warning"
        case .error: "error"
        }
    }
}
