//
//  MBCodable.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/9/1.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

public protocol MBCodable {
    static func load(fromString string: String, coder: MBCoder) throws -> Self
    static func load(fromObject object: Any) throws -> Self

    init()
    func toCodableObject() -> Any?
    func toString(coder: MBCoder, sortedKeys: Bool, prettyPrinted: Bool) throws -> String
}

public extension MBCodable {
    static func load(fromString string: String, coder: MBCoder) throws -> Self {
        guard let object = try coder.decode(string: string), !(object is NSNull) else {
            throw RuntimeError("[\(coder)] Decode string failed!")
        }
        return try load(fromObject: object)
    }

    static func load(fromObject object: Any) throws -> Self {
        if let v = object as? Self {
            return v
        }
        throw RuntimeError("Decode \(object) to \(Self.self) failed!")
    }

    func toString(coder: MBCoder, sortedKeys: Bool = true, prettyPrinted: Bool = true) throws -> String {
        guard let object = self.toCodableObject() else { return "" }
        return try coder.encode(object: object, sortedKeys: sortedKeys, prettyPrinted: prettyPrinted)
    }

    func toCodableObject() -> Any? {
        return self
    }

    var description: String {
        return (try? toString(coder: .json)) ?? ""
    }
}

open class MBCodableObject: NSObject, MBCodable {

    public required override init() {
        super.init()
        bindProperties()
    }

    public required init(dictionary: [String: Any]) {
        super.init()
        self.dictionary = self.prepare(dictionary: dictionary)
        bindProperties()
    }

    open var dictionary: [String : Any] = [:]
    open func value<T: MBCodable>(forPath path: String) -> T? {
        guard let value = self.dictionary.valueForKeyPath(path) else { return nil }
        if let v = value as? T {
            return v
        }
        if let v = try? T.load(fromObject: value) {
            self.setValue(v, forPath: path)
            return v
        }
        return nil
    }
    open func value<T: MBCodable>(forPath path: String, creator: ((T) -> Void)? = nil) -> T {
        if let v: T = self.value(forPath: path) { return v }
        let v = T.init()
        if let creator = creator {
            creator(v)
        }
        self.setValue(v, forPath: path)
        return v
    }
//    open func value(forPath path: String) -> MBCodable? {
//        let mirror = Mirror(reflecting: self)
//        let paths = path.components(separatedBy: ".")
//        guard let name = paths.first else { return nil }
//        let property = mirror.children.first { $0.label == name }
//        if property.
//    }
    open func setValue(_ value: MBCodable?, forPath path: String) {
        self.dictionary.setValue(value, forKeyPath: path)
    }

    public static func load(fromObject object: Any) throws -> Self {
        guard let dictionary = object as? [String: Any] else {
            throw NSError(domain: "Convert Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "类型不匹配 \(self): \(object)"])
        }
        let item = self.init(dictionary: dictionary)
        return item
    }

    open func prepare(dictionary: [String: Any]) -> [String: Any] {
        return dictionary
    }

    open func toCodableObject() -> Any? {
        return self.dictionary.compactMapValues { $0 }.toCodableObject()
    }

    open func bindProperties() {
        var mirror: Mirror? = Mirror(reflecting: self)
        while let m = mirror {
            for child in m.children {
                if var property = child.value as? CodableProperty {
                    if let label = child.label {
                        property.name = String(label.dropFirst())
                        if property.keys.isEmpty {
                            property.keys = [property.name!.convertSnakeCased()]
                        }
                    }
                    property.instance = self
                }
            }
            mirror = m.superclassMirror
        }
    }

    open override func value(forUndefinedKey key: String) -> Any? {
        return nil
    }

    open override func setValue(_ value: Any?, forUndefinedKey key: String) {

    }

    open override func setNilValueForKey(_ key: String) {
        var mirror: Mirror? = Mirror(reflecting: self)
        while let m = mirror {
            for child in m.children {
                if let label = child.label, String(label.dropFirst()) != key {
                    continue
                }
                if let property = child.value as? CodableProperty,
                    let jsonKey = property.key {
                    self.dictionary.removeValue(forKey: jsonKey)
                }
                return
            }
            mirror = m.superclassMirror
        }
    }

    open override func copy() -> Any {
        return Self.init(dictionary: self.dictionary)
    }
}

extension String: MBCodable {
    public static func load(fromObject object: Any) throws -> Self {
        if let i = object as? Int {
            return "\(i)"
        }
        return "\(object)"
    }
}
extension NSNumber: MBCodable {}
extension Int: MBCodable {}
extension Bool: MBCodable {}
extension Date: MBCodable {
    public static func load(fromObject object: Any) throws -> Date {
        if let string = object as? String,
            let date = Date(iso8601String: string) {
            return date
        }
        if let date = object as? Date {
            return date
        }
        throw NSError(domain: "Convert Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "类型不匹配 \(self): \(object)"])
    }

    public func toCodableObject() -> Any? {
        return self.iso8601String
    }
}

extension Array: MBCodable where Element: MBCodable {

    public static func load(fromObject object: Any) throws -> Self {
        if let object = object as? Self {
            return object
        }
        if let object = object as? [Any] {
            return try object.compactMap {
                try Element.load(fromObject: $0)
            }
        }
        return try [Element.load(fromObject: object)]
    }

    public func toCodableObject() -> Any? {
        return self.compactMap { $0.toCodableObject() }
    }
}

typealias OptionalAny = Optional<Any>
extension Dictionary: MBCodable {
    public func toCodableObject() -> Any? {
        return self.mapValues({ value -> Any? in
            if case let OptionalAny.some(obj) = (value as Any) {
                if let obj = obj as? MBCodable {
                    return obj.toCodableObject()
                } else if let dict = value as? [String: Any] {
                    return dict.toCodableObject()
                }
                return value
            } else {
                return nil
            }
        })
    }

    public static func load(fromObject object: Any) throws -> Self {
        guard let k = Key.self as? MBCodable.Type,
            let v = Value.self as? MBCodable.Type else {
                return object as! Dictionary<Key, Value>
        }
        guard let dict = object as? [AnyHashable: Any] else {
            throw NSError(domain: "Convert Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "类型不匹配 \(self): \(object)"])
        }
        return try Dictionary(uniqueKeysWithValues: dict.map { key, value in
            try (k.load(fromObject: key), v.load(fromObject: value)) as! (Key, Value)
        })
    }
}

extension Optional: MBCodable where Wrapped: MBCodable {
    public init() {
        let w = Wrapped.init()
        self = .some(w)
    }

    public static func load(fromObject object: Any) throws -> Self {
        if object is NSNull { return .none }
        return try Wrapped.load(fromObject: object)
    }

    public func toCodableObject() -> Any? {
        if let value = self {
            return value.toCodableObject()
        }
        return .none
    }

    public var description: String {
        if let value = self as? CustomStringConvertible {
            return value.description
        }
        return (self as MBCodable).description
    }
}
