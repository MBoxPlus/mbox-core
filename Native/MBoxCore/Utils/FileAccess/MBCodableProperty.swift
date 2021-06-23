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
    var key: String? { get set }
    var instance: AnyObject? { get set }
}

@propertyWrapper
public class Codable<T: CodableType>: CodableProperty {
    public var key: String? = nil
    public var name: String? = nil
    let defaultValue: () -> T
    var setterTransform: ((T, AnyObject)->(T))? = nil
    var getterTransform: ((Any?, AnyObject)->(T))? = nil
    var cacheTransform: Bool = false
    var transform: Bool = false
    public weak var instance: AnyObject?

    public init() {
        self.defaultValue = { return T.defaultValue() }
    }

    public init(key: String) {
        self.key = key
        self.defaultValue = { return T.defaultValue() }
    }

    public init(wrappedValue value: @autoclosure @escaping () -> T) {
        self.defaultValue = value
    }

    public init(wrappedValue value: @autoclosure @escaping () -> T, key: String? = nil) {
        self.key = key
        self.defaultValue = value
    }

    public init(getterTransform: @escaping (Any?, AnyObject) -> (T)) {
        self.defaultValue = { return T.defaultValue() }
        self.getterTransform = getterTransform
    }

    public init(key: String, cacheTransform: Bool = false, getterTransform: @escaping (Any?, AnyObject) -> (T)) {
        self.key = key
        self.cacheTransform = cacheTransform
        self.defaultValue = { return T.defaultValue() }
        self.getterTransform = getterTransform
    }

    public init(setterTransform: @escaping (T, AnyObject) -> (T)) {
        self.defaultValue = { return T.defaultValue() }
        self.setterTransform = setterTransform
    }

    public init(key: String, setterTransform: @escaping (T, AnyObject) -> (T)) {
        self.key = key
        self.defaultValue = { return T.defaultValue() }
        self.setterTransform = setterTransform
    }

    public var wrappedValue: T {
        get {
            guard let key = self.key,
                let instance = self.instance as? MBCodableObject else {
                    return defaultValue()
            }
            var value = instance.dictionary[key]
            if value is NSNull {
                value = nil
            }
            if value == nil,
               let name = self.name,
               let v = instance.dictionary[name],
               !(v is NSNull) {
                value = v
            }
            if !cacheTransform || !transform {
                if let getterTransform = self.getterTransform {
                    value = getterTransform(value, instance)
                    transform = true
                } else {
                    if let v = value,
                        !(value is T),
                        let t = T.self as? MBCodable.Type {
                        value = (try? t.load(fromObject: v)) as Any
                        transform = true
                    }
                }

                if value == nil && !(T.self is Optional<Any>.Type) {
                    value = defaultValue()
                }

                let obj = value as Any
                if case Optional<Any>.none = obj {
                    instance.dictionary.removeValue(forKey: key)
                } else {
                    instance.dictionary[key] = value
                }
            }

            // 转换为 Any，防止强制转换警告
            let result = value as Any
            return (result as! T)
        }
        set {
            var value: T
            if !((newValue as Any) is T), let t = T.self as? MBCodable.Type {
                value = try! t.load(fromObject: newValue) as! T
            } else {
                value = newValue
            }
            if let key = self.key, let instance = self.instance as? MBCodableObject {
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
