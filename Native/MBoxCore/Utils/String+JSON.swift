//
//  String+JSON.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/9/13.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

extension String {
    public func toJSONDictionary() -> [String: Any]? {
        if let data = self.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    public func toJSONArray() -> [Any]? {
        if let data = self.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}

public protocol JSONSerializable {
    func toJSONString(pretty: Bool) -> String?
}

extension Dictionary: JSONSerializable where Key == String, Value: Any{
    public func toJSONString(pretty: Bool = true) -> String? {
        guard let obj = self.toCodableObject() else { return nil }
        var options: JSONSerialization.WritingOptions = []
        if pretty {
            options.insert(.prettyPrinted)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: options) else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8)
    }
}

extension NSDictionary: JSONSerializable {
    public func toJSONString(pretty: Bool = true) -> String? {
        if let v = self as? [String: Any] {
            return v.toJSONString(pretty: pretty)
        }
        return nil
    }
}

extension Array: JSONSerializable {
    public func toJSONString(pretty: Bool = true) -> String? {
        var options: JSONSerialization.WritingOptions = []
        if pretty {
            options.insert(.prettyPrinted)
        }
        guard let data = try? JSONSerialization.data(withJSONObject: self, options: options) else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8)
    }
}

extension NSArray: JSONSerializable {
    public func toJSONString(pretty: Bool = true) -> String? {
        return (self as Array).toJSONString(pretty: pretty)
    }
}
