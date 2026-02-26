//
//  JSONChildrenWrapper.swift
//  hunch
//

import Foundation

/// Ensures JSON data for block children is wrapped in a `{"children": [...]}` envelope.
///
/// - If the input is a bare JSON array `[...]`, wraps it as `{"children": [...]}`.
/// - If it already has a top-level `{"children": [...]}` key, passes through unchanged.
/// - Any other JSON object passes through unchanged.
public enum JSONChildrenWrapper {
    public static func wrapIfNeeded(_ data: Data) -> Data {
        guard let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return data
        }

        if let array = parsed as? [Any] {
            let wrapped: [String: Any] = ["children": array]
            if let wrappedData = try? JSONSerialization.data(withJSONObject: wrapped) {
                return wrappedData
            }
            return data
        }

        return data
    }
}
