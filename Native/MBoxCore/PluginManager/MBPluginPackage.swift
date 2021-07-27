//
//  MBPluginPackage.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2020/3/12.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

public final class MBPluginPackage: MBCodableObject, MBYAMLProtocol {

    @Codable(key: "FORWARD_DEPENDENCIES")
    public var forwardDependencies: [String: String?]?

    @Codable(key: "DEPENDENCIES")
    public var dependencies: [String]?

    @Codable(key: "NATIVE_DEPENDENCIES")
    public var native_dependencies: [String: [String]]?

    public func dependencies(for name: String? = nil) -> [String]? {
        guard let name = name else { return self.dependencies }
        if name.isEmpty {
            return dependencies
        }
        return native_dependencies?[name]
    }

    @Codable(key: "NAME")
    public var name: String

    @Codable(key: "ALIAS")
    public var alias: [String]?

    @Codable(key: "CLI")
    public var CLI: Bool?

    @Codable(key: "SWIFT_VERSION")
    public var swiftVersion: String?

    @Codable(key: "GUI")
    public var GUI: Bool?

    @Codable(key: "GROUPS")
    public var groups: [String]?

    public var names: [String] {
        var names = [name]
        if let alias = self.alias {
            names.append(contentsOf: alias)
        }
        return names
    }

    public func isPlugin(_ name: String) -> Bool {
        return names.map { $0.lowercased() }.contains(name.lowercased())
    }

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

    @Codable(key: "REQUIRED")
    public var required: Bool = false

    public enum MBPluginScope: String, CaseIterable {
        case APPLICATION = "APPLICATION"
        case WORKSPACE = "WORKSPACE"
        case REPOSITORY = "REPOSITORY"

        public func capitalizedFirstLetterValue() -> String {
            return self.rawValue.capitalizedFirstLetter
        }
    }

    public var scope: MBPluginScope {
        set {
            self.dictionary["SCOPE"] = MBPluginScope(rawValue: newValue.rawValue)
        }
        get {
            if let scope = self.dictionary["SCOPE"] as? String {
                for c in MBPluginScope.allCases {
                    if c.rawValue == scope {
                        return c
                    }
                }
            }
            return .WORKSPACE
        }
    }
    public lazy var settingSchema: MBPluginSettingSchema? = .from(directory: path)

    public var path: String!

    public class func from(directory: String) -> MBPluginPackage? {
        let path = directory.appending(pathComponent: "manifest.yml")
        let package: MBPluginPackage? = self.load(fromFile: path)
        package?.path = directory
        return package
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

    public var isUnderDevelopment: Bool = false

    public var isInApplication: Bool = false

    public var isInUserDirectory: Bool = false

    public lazy var dataDir: String = MBSetting.globalDir.appending(pathComponent: "data/\(self.name)")

    // MARK: - Native
    public lazy var nativeBundleDir: String? = {
        guard self.CLI == true, let dir = self.dir else { return nil }
        let count = dir.subDirectories.filter {
            $0.pathExtension == "framework"
        }.count
        return count == 0 ? nil : dir
    }()

    public lazy var pluginBundles: [PluginBundle] = {
        guard let dir = nativeBundleDir else { return [] }
        let bundles = dir.subDirectories.filter {
            $0.pathExtension == "framework"
        }
        return bundles.map { path in
            let name = path.lastPathComponent.deletingPathExtension
            return PluginBundle(name: name.deletePrefix(self.name),
                                path: path,
                                package: self)
        }
    }()

    public lazy var defaultBundle: PluginBundle? = {
        return pluginBundle()
    }()

    public lazy var loaderBundle: PluginBundle? = {
        return pluginBundle(for: "Loader")
    }()

    public func pluginBundle(for name: String? = nil) -> PluginBundle? {
        return self.pluginBundles.first { $0.name == (name ?? "") }
    }

    @discardableResult
    public func load() -> Bool {
        return self.defaultBundle?.load() ?? false
    }

    @discardableResult
    public func unload() -> Bool {
        return self.defaultBundle?.unload() ?? true
    }

    public func registerCommanders() {
        for bundle in self.pluginBundles where bundle.isLoaded {
            bundle.registerCommanders()
        }
    }

    // MARK: - Ruby
    @Codable(key: "RUBY")
    public var hasRuby: Bool = false

    public lazy var rubyDir: String? = {
        guard hasRuby else { return nil }
        let path = self.path.appending(pathComponent: "Ruby")
        guard path.isDirectory else { return nil }
        return path
    }()

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

    public override var description: String {
        return "<MBPluginPackage \(self.name) (\(self.path ?? ""))>"
    }

    dynamic
    public func detailDescription(required: [String]? = nil, depended: [String]? = nil) -> String {
        var desc = name.ANSI(.yellow) + " " + "(\(version))".ANSI(.magenta) + ":"
        desc <<< "  PATH: \(self.path ?? "")"
        if let dir = self.nativeBundleDir, self.path != dir {
            desc <<< "  FRAMEWORK: \(dir)"
        }
        if let alias = self.alias, !alias.isEmpty {
            desc <<< "  ALIAS: \(alias.joined(separator: ", "))"
        }
        if let commitID = self.commitID {
            desc <<< "  COMMIT: \(commitID)"
        }
        if let commitDate = self.commitDate {
            desc <<< "  DATE: \(commitDate)"
        }
        if self.required {
            desc <<< "  REQUIRED: true"
        }
        let fowardDps = self.forwardDependencies?.map { $0.key } ?? []
        let dps = (self.dependencies ?? []) + fowardDps
        if !dps.isEmpty {
            desc <<< "  DEPENDENCIES:"
            for dp in dps.sorted() {
                if fowardDps.contains(dp) {
                    desc <<< "    - \(dp) (Forward)"
                } else {
                    desc <<< "    - \(dp)"
                }
            }
        }
        if let forward = self.forwardDependencies, !forward.isEmpty {

        }
        if let required = required, !required.isEmpty {
            desc <<< "  REQUIRED BY:"
            for dp in required {
                desc <<< "    - \(dp)"
            }
        }
        if let depended = depended, !depended.isEmpty {
            desc <<< "  DEPENDED ON:"
            for dp in depended {
                desc <<< "    - \(dp)"
            }
        }
        return desc
    }
}
