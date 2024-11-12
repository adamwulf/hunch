//
//  NotionItem.swift
//  hunch
//
//  Created by Adam Wulf on 11/12/24.
//

import Foundation

protocol NotionItem: Codable, CustomStringConvertible {
    var object: String { get }
    var id: String { get }
    var parent: Parent? { get }
}
