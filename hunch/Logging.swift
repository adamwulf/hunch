//
//  Logging.swift
//  hunch
//
//  Created by Adam Wulf on 6/23/24.
//

import OSLog

var log = Logger(subsystem: "com.milestonemade.hunch", category: "hunch")

enum Logging {
    static func configure() {
        NotionAPI.logHandler = { (_ logLevel: OSLogType, _ message: String, _ context: [String: Any]?) in
            log(logLevel, message, context: context)
        }
    }
}

func log(_ logLevel: OSLogType, _ message: String, context: [String: Any]? = nil) {
//    log.log(level: logLevel, "\(message) \(String.logfmt(context ?? [:]))")
}
