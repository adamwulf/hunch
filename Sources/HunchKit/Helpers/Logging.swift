//
//  Logging.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import OSLog
import SwiftToolbox
import Logfmt

var log = Logger(subsystem: "com.milestonemade.hunch", category: "hunch")

public enum Logging {
    public static func configure() {
        NotionAPI.logHandler = { (_ logLevel: OSLogType, _ message: String, _ context: [String: Any]?) in
            log(logLevel, message, context: context)
        }
    }
}

public func log(_ logLevel: OSLogType, _ message: String, context: [String: Any]? = nil) {
    log.log(level: logLevel, "\(message) \(String.logfmt(context ?? [:]))")
}
