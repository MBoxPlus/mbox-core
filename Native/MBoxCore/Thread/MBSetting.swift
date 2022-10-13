//
//  MBSetting.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/11/27.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation


open class MBSetting: MBCodableObject, MBJSONProtocol {

    public static var globalDir = FileManager.home.appending(pathComponent: ".mbox")

    open class PluginDescriptor: MBCodableObject {

        public typealias RequiredByKey = String

        public static let PluginDescriptorLatestVersion = "latest"

        @Codable
        open var required: Bool = true

        // 'latest' or 'x.y.z'
        @Codable
        open var requiredMinimumVersion: String?

        @Codable
        open var onlyContainer: Bool = false

        @Codable
        open var versions: [String]?

        open var requiredBy: String?

        public convenience init(dictionary: [String : Any]? = nil, requiredBy: String) {
            self.init(dictionary: dictionary ?? [:])
            self.requiredBy = requiredBy
        }

        public static func maxRequiredMinimumVersion(version1: String?, version2: String?) -> String? {
            guard let v1 = version1 else {
                return version2
            }
            guard let v2 = version2 else {
                return version1
            }
            if v1 == PluginDescriptorLatestVersion || v2 == PluginDescriptorLatestVersion {
                return PluginDescriptorLatestVersion
            }
            return v1.isVersion(greaterThanOrEqualTo: v2) ? v1 : v2
        }

        open override var description: String {
            var value = [String]()
            if self.required {
                value << "REQUIRED: true"
            }
            if let requiredMinimumVersion = self.requiredMinimumVersion {
                value << "> \(requiredMinimumVersion)"
            }
            if let requiredBy = self.requiredBy {
                value << "REQUIRED BY: \(requiredBy)"
            }
            return value.joined(separator: ", ")
        }
    }

    public static func pluginName(for string: String) -> String {
        var name = string
        if name.lowercased().hasPrefix("mbox") {
            let index = name.index(name.startIndex, offsetBy: 4)
            name = String(name.suffix(from: index))
        }
        return "MBox\(name.capitalizedFirstLetter)"
    }

    @Codable(keys: ["plugins2", "plugins"], mainKey: "plugins", getterTransform: { (value, instance) in
        guard let self = instance as? MBSetting else {
            return nil
        }
        if let v = value as? [String] {
            var result = [String: PluginDescriptor]()
            for name in v {
                result[MBSetting.pluginName(for: name)] = PluginDescriptor(requiredBy: self.name)
            }
            return result
        } else if let hash = value as? [String: [String: Any]] {
            return hash.mapKeysAndValues { (k, v) in
                return (MBSetting.pluginName(for: k), PluginDescriptor(dictionary: v, requiredBy: self.name))
            }
        }
        return nil
    })
    open var plugins: [String: PluginDescriptor]?

    public var filePath: String?
    public var name: String!
    public private(set) var readonly: Bool = false

    private convenience init(path: String) {
        self.init()
        self.filePath = path
    }

    private convenience init(name: String) {
        self.init()
        self.name = name
    }

    dynamic
    open func addPlugin(_ name: String) throws -> Bool {
        if self.readonly {
            return false
        }
        if plugins == nil {
            plugins = [:]
        }
        var pluginName = Self.pluginName(for: name).lowercased()
        if plugins!.keys.map({ $0.lowercased() }).contains(pluginName) {
            return false
        }
        if let package = MBPluginManager.shared.package(for: pluginName) {
            pluginName = package.name
        }
        plugins![pluginName] = PluginDescriptor(requiredBy: self.name)
        return true
    }

    open func removePlugin(_ name: String) -> Bool {
        if self.readonly {
            return false
        }
        let name = Self.pluginName(for: name).lowercased()
        if plugins == nil { return false }
        var status = false
        for n in plugins!.keys {
            if name == n.lowercased() {
                plugins?.removeValue(forKey: n)
                status = true
            }
        }
        return status
    }

    open func merge(_ other: MBSetting) {
        let plugins = self.plugins ?? [:]
        var objMap = self.dictionary.toCodableObject() as! Dictionary<String, Any>
        objMap.deepMerge(other.dictionary) { (keyPath, a, b) in
            if Set(["cocoapods.podspecs", "node.launches", "node.packages"]).contains(keyPath), let a = a as? [String], let b = b as? [String] {
                return (a + b).withoutDuplicates()
            }
            return b
        }
        self.dictionary = objMap
        var newPlugins = self.plugins ?? [:]
        for name in newPlugins.keys {
            guard let newDesc = newPlugins[name],
                  let desc = plugins[name] else {
                continue
            }
            newDesc.onlyContainer = newDesc.onlyContainer && desc.onlyContainer
            newDesc.required = newDesc.required || desc.required
            newDesc.versions ?= []
            newDesc.versions!.append(contentsOf: desc.versions ?? [])
            newDesc.requiredMinimumVersion = PluginDescriptor.maxRequiredMinimumVersion(version1: newDesc.requiredMinimumVersion, version2: desc.requiredMinimumVersion)
            newPlugins[name] = newDesc
        }
        if newPlugins.isEmpty {
            self.plugins = nil
        } else {
            self.plugins = newPlugins
        }
    }
}

extension MBSetting {
    public static func load(fromFile path: String, name: String) -> MBSetting {
        let setting = MBSetting.load(fromFile: path) ?? MBSetting(path: path)
        setting.name = name
        return setting
    }

    public static let global: MBSetting = MBSetting.load(fromFile: globalDir.appending(pathComponent: "config.json"), name: "Global Setting")

    dynamic
    public static var merged: MBSetting {
        let merged = MBSetting(name: "Merged Readonly Setting")
        merged.readonly = true
        merged.merge(global)
        return merged
    }

    dynamic
    public static var all: [MBSetting] {
        return [global]
    }
}

extension MBSetting {
    public class Core: MBCodableObject {
        @Codable(key: "dev-root")
        public var devRoot: String?
    }

    public var core: Core? {
        set {
            self.dictionary["core"] = newValue
        }
        get {
            return self.value(forPath: "core")
        }
    }
}
