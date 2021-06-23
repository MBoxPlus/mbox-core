//
//  Dictionary+KeyPath.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2019/12/17.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension Dictionary {
    mutating public func setValue(_ value: Any?, forKeyPath keyPath: String) {
        var keys = keyPath.components(separatedBy: ".")
        guard let first = keys.first as? Key else { print("Unable to use string as key on type: \(Key.self)"); return }
        keys.remove(at: 0)
        if keys.isEmpty {
            if let settable = value as? Value {
                self[first] = settable
            } else {
                self.removeValue(forKey: first)
            }
        } else {
            let rejoined = keys.joined(separator: ".")
            var subdict: [NSObject : AnyObject] = [:]
            if let sub = self[first] as? [NSObject : AnyObject] {
                subdict = sub
            }
            subdict.setValue(value, forKeyPath: rejoined)
            if let settable = subdict as? Value {
                self[first] = settable
            } else {
                print("Unable to set value: \(subdict) to dictionary of type: \(type(of: self))")
            }
        }

    }

    public func valueForKeyPath(_ keyPath: String) -> Any? {
        var keys = keyPath.components(separatedBy: ".")
        guard let first = keys.first as? Key else { print("Unable to use string as key on type: \(Key.self)"); return nil }
        guard let value = self[first] else { return nil }
        keys.remove(at: 0)
        if !keys.isEmpty, let subDict = (value as? [String : Any]) ?? (value as? MBCodableObject)?.dictionary {
            let rejoined = keys.joined(separator: ".")

            return subDict.valueForKeyPath(rejoined)
        }

        if case let OptionalAny.some(obj) = (value as Any) {
            return obj
        }
        return nil
    }
}
