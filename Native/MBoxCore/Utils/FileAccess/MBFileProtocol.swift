//
//  MBFileProtocol.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/29.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation

dynamic
public func coder(for extension: String) -> MBCoder? {
    switch `extension`.lowercased() {
    case ".json":
        return MBJSONCoder.shared
    case ".yml", ".yaml":
        return MBYAMLCoder.shared
    default:
        return nil
    }
}

public protocol MBFileProtocol: MBCodable {

    static var defaultCoder: MBCoder? { get }

    var filePath: String? { set get }
    var dir: String? { get }

    @discardableResult
    func save(filePath: String?, sortedKeys: Bool, prettyPrinted: Bool) -> Bool

    static func load(fromFile path: String) -> Self?
    static func load(fromFile path: String) -> Self
}

private var MBFileProtocolPathKey: UInt8 = 0
extension MBFileProtocol {

    public static var defaultCoder: MBCoder? {
        return nil
    }

    public var filePath: String? {
        set {
            associateObject(base: self as AnyObject, key: &MBFileProtocolPathKey, value: newValue)
        }
        get {
            return associatedObject(base: self as AnyObject, key: &MBFileProtocolPathKey)
        }
    }

    public var dir: String? {
        return filePath?.deletingLastPathComponent
    }

    @discardableResult
    public func save(filePath: String? = nil, sortedKeys: Bool = true, prettyPrinted: Bool = true) -> Bool {
        guard let path = filePath ?? self.filePath else {
            UI.log(error: "Save file failed: The file path is null.")
            return false
        }
        guard let coder = coder(for: path.pathExtension) ?? Self.defaultCoder else { return false }
        do {
            let string = try toString(coder: coder, sortedKeys: sortedKeys, prettyPrinted: prettyPrinted)
            try? FileManager.default.createDirectory(atPath: path.deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
            UI.log(verbose: "Save file `\(path)`...")
            try string.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
            return true
        } catch {
            UI.log(error: "Save file failed: \(path)\n\t\(error)")
            return false
        }
    }

    public static func load(fromFile path: String, coder custom: MBCoder? = Self.defaultCoder) throws -> Self {
        guard let coder = custom ?? coder(for: path.pathExtension) else {
            throw RuntimeError("Unknown file coder for `\(path)`.")
        }
        if FileManager.default.fileExists(atPath: path) {
            do {
                let content = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
                var item = try load(fromString: content, coder: coder)
                item.filePath = path
                return item
            } catch {
                UI.log(error: "Decode failed: \(path)\n\t\(error.localizedDescription)")
            }
        }
        var item = Self.init()
        item.filePath = path
        item.save(filePath: path)
        return item
    }

    public static func load(fromFile path: String) -> Self? {
        if !FileManager.default.fileExists(atPath: path) { return nil }
        guard let coder = coder(for: path.pathExtension) ?? Self.defaultCoder else { return nil }
        do {
            let content = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
            var item = try load(fromString: content, coder: coder)
            item.filePath = path
            return item
        } catch {
            UI.log(error: "Decode failed: \(path)\n\t\(error.localizedDescription)")
        }
        return nil
    }

    public static func load(fromFile path: String) -> Self {
        if let obj = self.load(fromFile: path) {
            return obj
        }
        var obj = self.init()
        obj.filePath = path
        return obj
    }
}

extension Array: MBFileProtocol where Element: MBFileProtocol {
    public static var defaultCoder: MBCoder? {
        return Element.defaultCoder
    }
}

extension Dictionary: MBFileProtocol {
}
