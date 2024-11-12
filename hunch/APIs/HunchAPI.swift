//
//  HunchAPI.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation
import OSLog

class HunchAPI {
    public static var logHandler: ((_ level: OSLogType, _ message: String, _ context: [String: Any]?) -> Void)?
    public static let shared = HunchAPI(notion: NotionAPI.shared)

    public let notion: NotionAPI

    private init(notion: NotionAPI) {
        self.notion = notion
    }
}
