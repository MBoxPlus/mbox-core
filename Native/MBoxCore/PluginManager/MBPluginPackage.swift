//
//  MBPluginPackage.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/3/12.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

public final class MBPluginPackage: MBPluginModule {

    @Codable(key: "VERSION")
    public var version: String

    @Codable(key: "BUILD_DATE")
    public var buildDate: String?

    @Codable(key: "BUILD_NUMBER")
    public var buildNumber: String?

    @Codable(key: "COMMIT_ID")
    public var commitID: String?

    @Codable(key: "COMMIT_DATE")
    public var commitDate: String?

    @Codable(key: "PUBLISHER")
    public var publisher: String?

    @Codable(key: "AUTHORS")
    public var authors: [String]?

    @Codable(key: "HOMEPAGE")
    public var homepage: String?

    @Codable(key: "GIT_URL")
    public var gitURL: String?

    @Codable(key: "ICON")
    public var icon: String?

    @Codable(key: "MINIMUM_VERSION")
    public var minimum_version: String?

    @Codable(key: "SWIFT_VERSION")
    public var swiftVersion: String?

    public override func bindProperties() {
        super.bindProperties()
        self.package = self
    }

    // MARK: - Module
    public lazy var allModules: [MBPluginModule] = [self] + self.allSubModules
    private lazy var allModulesHash: [String: MBPluginModule] = {
        return Dictionary(allModules.map { ($0.name.lowercased(), $0) } )
    }()
    public func module(named: String) -> MBPluginModule? {
        return self.allModulesHash[named.replacingOccurrences(of: "/", with: "").lowercased()]
    }

    public func createModule(name: String, root: String) throws -> MBPluginModule {
        if let module = self.module(named: name) { return module }
        let superName = name.split(separator: "/").dropLast().joined(separator: "/")
        guard let module = self.module(named: superName) else {
            throw UserError("Could not find parent module `\(superName)`.")
        }
        return module.createSubmodule(name: name, root: root)
    }

    // MARK: - Public class methods
    public class override func from(directory: String) -> MBPluginPackage? {
        let v = super.from(directory: directory) as? MBPluginPackage
        v?.package = v
        return v
    }

    public class func search(directory: String) -> [String: MBPluginPackage] {
        if !directory.isDirectory {
            return [:]
        }
        var pluginPaths = [String: MBPluginPackage]()
        for dir in directory.subDirectories {
            if dir.isDirectory,
                let package = MBPluginPackage.from(directory: dir) {
                pluginPaths[package.name] = package
            }
        }
        return pluginPaths
    }

    public class func packageName(for string: String) -> String {
        return String(string.split(separator: "/").first!)
    }

    // MAKR: - Status
    public var isUnderDevelopment: Bool = false

    public var isInApplication: Bool = false

    public var isInUserDirectory: Bool = false

    // MARK: - Data
    public lazy var dataDir: String = MBSetting.globalDir.appending(pathComponent: "data/\(self.name)")

    // MARK: - Resources
    public lazy var resourcesDir: String? = {
        let path = self.path.appending(pathComponent: "Resources")
        guard path.isDirectory else { return nil }
        return path
    }()

    public func resoucePath(for name: String) -> String? {
        guard let path = self.resourcesDir?.appending(pathComponent: name),
              path.isExists else {
            return nil
        }
        return path
    }

    // MARK: - Launcher
    @Codable(key: "LAUNCHER")
    public var hasLauncher: Bool = false

    public lazy var launcherDir: String? = {
        guard hasLauncher else { return nil }
        let path = self.path.appending(pathComponent: "Launcher")
        guard path.isDirectory else { return nil }
        return path
    }()

    public lazy var launcherItems: [MBPluginLaunchItem] = {
        guard let path = self.launcherDir?.appending(pathComponent: "manifest.yml"),
              path.isExists else { return [] }
        guard let data = try? [String: Any].load(fromFile: path, coder: .yaml) else { return [] }
        var items = [MBPluginLaunchItem]()
        for (name, info) in data {
            let item = MBPluginLaunchItem(dictionary: (info as? [String: Any]) ?? [:])
            item.setName(name, in: self)
            items.append(item)
        }
        return items
    }()

    // MARK: - Description
    public override var description: String {
        return "\(self.name) (\(self.version)) \(self.path.ANSI(.black, bright: true))"
    }

    // MARK: - Merge
    override func merge(_ objects: [MBPluginModule]) {
        super.merge(objects)
        guard let packages = objects as? [MBPluginPackage] else {
            return
        }
        if self.resourcesDir == nil {
            self.resourcesDir = packages.firstMap { $0.resourcesDir }
        }
        if self.launcherDir == nil {
            self.launcherDir = packages.firstMap { $0.launcherDir }
        }
        if !self.isInApplication {
            self.isInApplication = packages.contains { $0.isInApplication }
        }
    }
}

extension MBPluginPackage: Comparable {

    public static func < (lhs: MBPluginPackage, rhs: MBPluginPackage) -> Bool {
        return lhs.name < rhs.name
    }

    public static func <= (lhs: MBPluginPackage, rhs: MBPluginPackage) -> Bool {
        return lhs.name <= rhs.name
    }

    public static func >= (lhs: MBPluginPackage, rhs: MBPluginPackage) -> Bool {
        return lhs.name >= rhs.name
    }

    public static func > (lhs: MBPluginPackage, rhs: MBPluginPackage) -> Bool {
        return lhs.name > rhs.name
    }
}
