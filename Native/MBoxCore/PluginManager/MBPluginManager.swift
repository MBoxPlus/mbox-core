//
//  MBPluginManager.swift
//  MBox
//
//  Created by Whirlwind on 2018/8/21.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation

public var RunUnderCommandLineMode: Bool = false

public protocol MBPluginProtocol {
    func registerCommanders()

    func installPlugin(from version: String?) throws
    func uninstallPlugin()
}

extension MBPluginProtocol {
    public func registerCommanders() {}

    public func installPlugin(from version: String?) throws {}
    public func uninstallPlugin() {}
}

public final class MBPluginManager: NSObject {

    public static let shared = MBPluginManager()
    public lazy var allPackages: [String: MBPluginPackage] = all()

    public private(set) var packages = Set<MBPluginPackage>()

    public func package(for name: String) -> MBPluginPackage? {
        let packages = Array(self.allPackages.values)
        return packages.first { $0.isPlugin(name) }
    }

    public func dependencies(for plugin: String) -> [MBPluginPackage] {
        var packages = [MBPluginPackage]()
        if let package = self.package(for: plugin) {
            if let dependencies = package.dependencies {
                for dp in dependencies {
                    for package in self.dependencies(for: dp) {
                        if !packages.contains(package) {
                            packages.append(package)
                        }
                    }
                }
            }
            packages.append(package)
        }
        return packages
    }

    public func dependencies(for plugins: [String]) -> [MBPluginPackage] {
        var values = [MBPluginPackage]()
        for plugin in plugins {
            for package in self.dependencies(for: plugin) {
                if !values.contains(package) {
                    values.append(package)
                }
            }
        }
        return values
    }

    public func all() -> [String: MBPluginPackage] {
        var plugins: [String: MBPluginPackage] = [:]

        logLoad("Search Plugins:")

        if let pluginPaths = try? UI.args.option(for: "plugin-paths", shift: true)?.split(separator: ":") {
            for path in pluginPaths {
                if let package = MBPluginPackage.from(directory: String(path)) {
                    plugins[package.name] = package
                }
            }

            if let devRoot = UI.devRoot {
                logLoad("  \(devRoot)")
                let devPlugins = MBPluginPackage.search(directory: devRoot)
                for (name, v) in devPlugins {
                    guard plugins.has(key: name) else { continue }
                    v.isUnderDevelopment = true
                    if v.CLI == true,
                       v.nativeBundleDir == nil {
                        let framework = devRoot.appending(pathComponent: "build/\(v.name)/\(v.name).framework")
                        if framework.isDirectory {
                            v.nativeBundleDir = framework.deletingLastPathComponent
                        }
                    }
                    if v.CLI == true,
                       v.nativeBundleDir == nil,
                       let releasePlugin = plugins[v.name] {
                        v.nativeBundleDir = releasePlugin.nativeBundleDir
                    }
                    plugins[v.name] = v
                }
            }

        } else {

            var appPluginPaths = [String]()
            if let appPluginPath = MBoxApp.path?.appending(pathComponent: "Contents/Resources/Plugins") {
                appPluginPaths.append(appPluginPath)
            }
            let appPluginPath = Self.bundle.bundlePath.appending(pathComponent: "../..").cleanPath
            if !appPluginPaths.contains(appPluginPath) {
                appPluginPaths.append(appPluginPath)
            }
            for path in appPluginPaths {
                logLoad("  \(path)")
                plugins.merge(MBPluginPackage.search(directory: path)) { (a, b) in
                    return b
                }
            }

            plugins.forEach { (_, v) in
                v.isInApplication = true
            }

            let homePluginPath = MBSetting.globalDir.appending(pathComponent: "plugins")
            logLoad("  \(homePluginPath)")
            let globalPlugins = MBPluginPackage.search(directory: homePluginPath)
            globalPlugins.forEach { (_, v) in
                v.isInUserDirectory = true
            }

            plugins.merge(globalPlugins) { (a, b) -> MBPluginPackage in
                return a.version.compare(b.version, options: .numeric) == .orderedDescending ? a : b
            }

            if let devRoot = UI.devRoot {
                logLoad("  \(devRoot)")
                var devPlugins = MBPluginPackage.search(directory: devRoot)
                if let coreDev = devPlugins.removeValue(forKey: "MBoxCore") {
                    coreDev.nativeBundleDir = self.bundle.bundlePath.deletingLastPathComponent
                    coreDev.isUnderDevelopment = true
                    plugins[coreDev.name] = coreDev
                }
                for (_, v) in devPlugins {
                    v.isUnderDevelopment = true
                    if v.CLI == true,
                       v.nativeBundleDir == nil {
                        let framework = devRoot.appending(pathComponent: "build/\(v.name)/\(v.name).framework")
                        if framework.isDirectory {
                            v.nativeBundleDir = framework.deletingLastPathComponent
                        }
                    }
                    if v.CLI == true,
                       v.nativeBundleDir == nil,
                       let releasePlugin = plugins[v.name] {
                        v.nativeBundleDir = releasePlugin.nativeBundleDir
                    }
                    plugins[v.name] = v
                }
            }
        }

        logLoad("Found Plugins:", items: plugins.map(\.value).sorted(by: \.name).map { "\($0.name) (\($0.path!))" })

        return plugins
    }

    public func pluginBundle(for bundleName: String) -> MBPluginPackage.PluginBundle? {
        var names = bundleName.split(separator: "/").map { String($0) }
        let name = names.removeFirst()
        guard let package = self.package(for: name) else { return nil }
        return package.pluginBundle(for: names.first)
    }

    @discardableResult
    public func load(pluginPackage: MBPluginPackage) -> Bool {
        guard let bundle = pluginPackage.defaultBundle else { return true }
        var loadedBundles = Set<MBPluginPackage.PluginBundle>()
        var failedBundles = Set<MBPluginPackage.PluginBundle>()
        return self.load(pluginBundle: bundle, loadedBundles: &loadedBundles, failedBundles: &failedBundles)
    }

    @discardableResult
    public func load(pluginBundle: MBPluginPackage.PluginBundle,
                     loadedBundles: inout Set<MBPluginPackage.PluginBundle>,
                     failedBundles: inout Set<MBPluginPackage.PluginBundle>) -> Bool {
        if loadedBundles.contains(pluginBundle) {
            return true
        }
        pluginBundle.dependencies?.forEach({ name in
            guard let bundle = self.pluginBundle(for: name) else { return }
            load(pluginBundle: bundle,
                 loadedBundles: &loadedBundles,
                 failedBundles: &failedBundles)
        })
        let package = pluginBundle.package!
        if package.CLI != true || pluginBundle.load() {
            if pluginBundle.name == "" {
                self.packages.insert(package)
            }
            loadedBundles.insert(pluginBundle)
            return true
        } else {
            failedBundles.insert(pluginBundle)
            return false
        }
    }

    public func unload(package: MBPluginPackage) -> Bool {
        if package.CLI == true, !package.unload() {
            return false
        }
        packages.remove(package)
        return true
    }

    public func loadAll() {
        // 1. Get All Packages
        let packages = self.allPackages.values
        var loadedBundles = Set<MBPluginPackage.PluginBundle>()
        var failedBundles = Set<MBPluginPackage.PluginBundle>()

        logLoad("Load Plugins...")

        // 2. Load Package Loader
        logLoad("Load Loader:")
        for bundle in packages.compactMap({ $0.pluginBundle(for: "Loader") }) {
            load(pluginBundle: bundle,
                 loadedBundles: &loadedBundles,
                 failedBundles: &failedBundles)
        }
        // 3. Load Required Packages ( without forward dependencies )
        logLoad("Load required plugin:")
        let requiredBundles = packages.filter{ $0.required && $0.forwardDependencies == nil }.compactMap { $0.defaultBundle }
        for bundle in requiredBundles {
            load(pluginBundle: bundle,
                 loadedBundles: &loadedBundles,
                 failedBundles: &failedBundles)
        }
        // 4. Load Plugins
        logLoad("Load user plugins:")
        for name in UI.cachedPlugins.keys {
            if let package = packages.first(where: { $0.isPlugin(name) }),
               package.forwardDependencies == nil {
                if let bundle = package.defaultBundle {
                    load(pluginBundle: bundle,
                         loadedBundles: &loadedBundles,
                         failedBundles: &failedBundles)
                } else {
                    self.packages.insert(package)
                }
            }
        }
        // 5. Load Plugins Again
        logLoad("Load user plugins again:")
        UI.cachedPlugins.merge(UI.plugins) { ($0 + $1).withoutDuplicates() }
        for name in UI.cachedPlugins.keys {
            if let package = packages.first(where: { $0.isPlugin(name) }),
               package.forwardDependencies == nil {
               if let bundle = package.defaultBundle {
                load(pluginBundle: bundle,
                     loadedBundles: &loadedBundles,
                     failedBundles: &failedBundles)
               } else {
                self.packages.insert(package)
               }
            }
        }
        // 6. Load Activated Plugins With Forward Dependencies
        logLoad("Load plugins with forward dependencies:")
        var forwardPackages = packages.filter { $0.forwardDependencies != nil }.filter { package in
            if package.required {
                return true
            }
            return UI.cachedPlugins.keys.contains { package.isPlugin($0) }
        }
        while true {
            var loaded = false
            for package in Array(forwardPackages) {
                guard let forwardDependencies = package.forwardDependencies,
                      forwardPackages.count > 0 else {
                    continue
                }
                let satisfied = self.isSatisfied(forwardDependencies,
                                                 in: loadedBundles.filter { $0.name.isEmpty }
                                                    .compactMap(\.package))
                if satisfied, let bundle = package.defaultBundle {
                    forwardPackages.removeAll(package)
                    if load(pluginBundle: bundle,
                            loadedBundles: &loadedBundles,
                            failedBundles: &failedBundles) {
                        loaded = true
                    }
                }
            }
            if !loaded {
                break
            }
        }
        if failedBundles.count > 0 {
            UI.log(warn: "Load Plugin Failed:", items: failedBundles.map { $0.name }, summary: false)
        }
    }

    private func isSatisfied(_ constraints: [String: String?], in packages: [MBPluginPackage]) -> Bool {
        for (name, _) in constraints {
            if !packages.contains(where: { $0.isPlugin(name) }) {
                return false
            }
        }
        return true
    }

    dynamic
    public func additionalPluginPackages() -> [String: [MBSetting.PluginDescriptor]] {
        return [:]
    }

    @discardableResult
    public func runAll() -> Set<MBPluginPackage> {
        self.loadAll()
        return packages
    }

    dynamic
    public func registerCommander() {
        for package in self.allPackages.values {
            package.registerCommanders()
        }
    }

    private func logLoad(_ msg: String,
                         items: [String]? = nil,
                         file: StaticString = #file,
                         function: StaticString = #function,
                         line: UInt = #line) {
        if ProcessInfo.processInfo.environment["DYLD_PRINT_LIBRARIES"] == "1" {
            UI.log(info: msg, items: items, pip: .ERR, file: file, function: function, line: line)
        }
    }
}

public func getModuleName(forClass: AnyClass) -> String {
    let bundle = Bundle(for: forClass)
    return bundle.name.deleteSuffix("Tests")
}

extension NSObject {
    public class var pluginPackage: MBPluginPackage? {
        let bundle = Bundle(for: self)
        let path = bundle.bundlePath.deletingLastPathComponent
        return MBPluginManager.shared.allPackages.values.first { $0.nativeBundleDir == path
        }
    }
}
