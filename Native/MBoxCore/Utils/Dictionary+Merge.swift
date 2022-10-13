//
//  Dictionary+Merge.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/12/18.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension Dictionary where Key == String {
    private mutating func deepMerge(_ other: [Key : Value], keyPath: String?, uniquingKeysWith combine: (String, Value, Value) throws -> Value) rethrows {
        let keys = Set(Array(self.keys) + Array(other.keys))
        for key in keys {
            let myValue = self[key]
            let otherValue = other[key]
            let k: String
            if let keyPath = keyPath {
                k = keyPath + "." + key
            } else {
                k = key
            }
            if let myValue = myValue, let otherValue = otherValue {
                if var currentDict = myValue as? Dictionary, let newDict = otherValue as? Dictionary {
                    try currentDict.deepMerge(newDict, keyPath: k, uniquingKeysWith: combine)
                    self[key] = (currentDict as! Value)
                }else {
                    self[key] = try combine(k, myValue, otherValue)
                }
            } else if myValue == nil, let otherValue = otherValue {
                self[key] = otherValue
            } else if let myValue = myValue, otherValue == nil {
                self[key] = myValue
            }
        }
    }

    mutating func deepMerge(_ other: [Key : Value], uniquingKeysWith combine: (String, Value, Value) throws -> Value) rethrows {
        try self.deepMerge(other, keyPath: nil, uniquingKeysWith: combine)
    }

    mutating func deepMerge(_ other: [Key : Value]) {
        self.deepMerge(other) { (_, _, new) in
            return new
        }
    }
}

public extension Dictionary where Value == [String] {
    mutating func mergeValue(_ dict: [Key: Value]) {
        merge(dict) { (current, new) in
            return Array(Set(current + new))
        }
    }
    func mergingValue(_ dict: [Key: Value]) -> [Key: Value] {
        var origin = self
        origin.mergeValue(dict)
        return origin
    }
}
