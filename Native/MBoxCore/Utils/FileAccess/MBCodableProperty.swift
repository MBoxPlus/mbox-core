//
//  MBCodableProperty.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/9/3.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

public protocol CodableProperty {
    var name: String? { get set }
    var keys: [String] { get set }
    var key: String? { get }
    var instance: AnyObject? { get set }
}

@propertyWrapper
public class Codable<T: CodableType>: CodableProperty {
    public var keys: [String] = []
    public var key: String? {
        return self.keys.first ?? self.name
    }
    public var mainKey: String?
    public var name: String? = nil
    let defaultValue: () -> T
    var setterTransform: ((T, AnyObject)->(T))? = nil
    var getterTransform: ((Any?, AnyObject)->(T))? = nil
    var transform: Bool = false
    public weak var instance: AnyObject?

    public init() {
        self.defaultValue = { return T.defaultValue() }
    }

    public init(key: String) {
        self.keys = [key]
        self.defaultValue = { return T.defaultValue() }
    }

    public init(wrappedValue value: @autoclosure @escaping () -> T) {
        self.defaultValue = value
    }

    public init(wrappedValue value: @autoclosure @escaping () -> T, key: String? = nil) {
        if let key = key {
            self.keys = [key]
        }
        self.defaultValue = value
    }

    public init(getterTransform: @escaping (Any?, AnyObject) -> (T)) {
        self.defaultValue = { return T.defaultValue() }
        self.getterTransform = getterTransform
    }

    public init(key: String, getterTransform: @escaping (Any?, AnyObject) -> (T)) {
        self.keys = [key]
        self.defaultValue = { return T.defaultValue() }
        self.getterTransform = getterTransform
    }

    public init(keys: [String], mainKey: String?, getterTransform: @escaping (Any?, AnyObject) -> (T)) {
        self.keys = keys
        self.mainKey = mainKey
        self.defaultValue = { return T.defaultValue() }
        self.getterTransform = getterTransform
    }

    public init(setterTransform: @escaping (T, AnyObject) -> (T)) {
        self.defaultValue = { return T.defaultValue() }
        self.setterTransform = setterTransform
    }

    public init(key: String, setterTransform: @escaping (T, AnyObject) -> (T)) {
        self.keys = [key]
        self.defaultValue = { return T.defaultValue() }
        self.setterTransform = setterTransform
    }

    private var names: [String] {
        var names = [String]()
        names.append(contentsOf: self.keys)
        if let name = self.name {
            names << name
        }
        return names
    }

    private func fetchValue() -> (key: String, value: Any?) {
        if let instance = self.instance as? MBCodableObject {
            for key in self.names {
                var value = instance.dictionary[key]
                if value is NSNull {
                    value = nil
                }
                if let v = value {
                    if case Optional<Any>.none = v {
                        continue
                    } else {
                        return (key: key, value: v)
                    }
                }
            }
        }
        return (key: self.names.first!, value: nil)
    }

    public var wrappedValue: T {
        get {
            guard let instance = self.instance as? MBCodableObject else {
                return defaultValue()
            }

            let (key, originValue) = self.fetchValue()
            if transform {
                return originValue as! T
            }
            var value: T
            if let getterTransform = self.getterTransform {
                value = getterTransform(originValue, instance)
            } else if let v = originValue as? T {
                value = v
            } else if let t = T.self as? MBCodable.Type,
                      let originValue = originValue,
                      let v = try? t.load(fromObject: originValue) as? T {
                value = v
            } else {
                value = defaultValue()
            }

            let obj = value as Any
            if case Optional<Any>.none = obj {
                value = defaultValue()
            }

            let obj2 = value as Any
            if case Optional<Any>.none = obj2 {
                instance.dictionary.removeValue(forKey: key)
            } else {
                for key in self.names {
                    instance.dictionary.removeValue(forKey: key)
                }
                let key = self.mainKey ?? self.names.first ?? key
                instance.dictionary[key] = value
            }
            transform = true
            return value
        }
        set {
            var value: T
            if !((newValue as Any) is T), let t = T.self as? MBCodable.Type {
                value = try! t.load(fromObject: newValue) as! T
            } else {
                value = newValue
            }
            if let key = self.keys.first, let instance = self.instance as? MBCodableObject {
                if let transform = self.setterTransform {
                    value = transform(value, instance)
                }
                // 判断是否为 nil 
                let obj = value as Any
                if case Optional<Any>.none = obj {
                    instance.dictionary.removeValue(forKey: key)
                } else {
                    instance.dictionary[key] = value
                }
                transform = true
            }
        }
    }
}

public protocol CodableType {
    static func defaultValue() -> Self
}

extension Optional: CodableType {
    public static func defaultValue() -> Self {
        return nil
    }
}

extension String: CodableType {
    public static func defaultValue() -> Self {
        return ""
    }
}

extension Bool: CodableType {
    public static func defaultValue() -> Self {
        return false
    }
}

extension Int: CodableType {
    public static func defaultValue() -> Self {
        return 0
    }
}

extension Array: CodableType {
    public static func defaultValue() -> Self {
        return []
    }
}

extension Dictionary: CodableType {
    public static func defaultValue() -> Self {
        return [:]
    }
}

extension Double: CodableType {
    public static func defaultValue() -> Self {
        return 0
    }
}

extension Float: CodableType {
    public static func defaultValue() -> Self {
        return 0
    }
}
