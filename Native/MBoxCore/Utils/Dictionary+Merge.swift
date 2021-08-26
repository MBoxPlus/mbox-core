//
//  Dictionary+Merge.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/12/18.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension Dictionary {
    mutating func deepMerge(_ dict: Dictionary) {
        merge(dict) { (current, new) in
            if var currentDict = current as? Dictionary, let newDict = new as? Dictionary {
                currentDict.deepMerge(newDict)
                return currentDict as! Value
            }
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
