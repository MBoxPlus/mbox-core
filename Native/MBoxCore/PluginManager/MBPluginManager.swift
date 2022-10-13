//
//  MBPluginManager.swift
//  MBox
//
//  Created by Whirlwind on 2018/8/21.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

public var RunUnderCommandLineMode: Bool = false

public protocol MBPluginProtocol {
    func registerCommanders()
}

public protocol MBPluginMigrateProtocol {
    func installPlugin(from version: String?) throws
    func uninstallPlugin()
}

var kMBThreadShouldOutputPluginLog: UInt8 = 0
extension MBThread {
    private var shouldOutputLog: Bool {
        return associatedObject(base: self, key: &kMBThreadShouldOutputPluginLog) {
            return ProcessInfo.processInfo.removeEnvironment(name: "MBOX_PRINT_PLUGIN") == "1"
        }
    }

    @inline(__always)
    func logLoad(_ msg: String,
                 items: (() -> [String])? = nil,
                 file: StaticString = #file,
                 function: StaticString = #function,
                 line: UInt = #line) {
        if self.shouldOutputLog {
            UI.log(info: msg, items: items?(), pip: .ERR, file: file, function: function, line: line)
        }
    }

    @discardableResult @inline(__always)
    func logLoad<T>(_ msg: String,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line,
                    block: () throws -> T) rethrows -> T {
        if self.shouldOutputLog {
            return try UI.log(info: msg, pip: .ERR, file: file, function: function, line: line, block: block)
        } else {
            return try block()
        }
    }
}
public final class MBPluginManager: NSObject {

    public static let shared = MBPluginManager()

    // MARK: - All Plugins
    public lazy var allPackages: [MBPluginPackage] = all() {
        didSet {
            self.allPackagesHash = self.generateAllPackagesHash()
            self.allModules = self.generateAllModules()
        }
    }

    private lazy var allPackagesHash: [String: MBPluginPackage] = self.generateAllPackagesHash()

    private func generateAllPackagesHash() -> [String: MBPluginPackage] {
        return Dictionary(self.allPackages.map { ($0.name.lowercased(), $0) })
    }

    public func package(for name: String) -> MBPluginPackage? {
        var name = name.lowercased()
        if !name.hasPrefix("mbox") {
            name = "mbox" + name
        }
        return allPackagesHash[name]
    }

    public private(set) lazy var allModules: [MBPluginModule] = self.generateAllModules() {
        didSet {
            self.allModulesHash = self.generateAllModulesHash()
        }
    }

    private lazy var allModulesHash: [String: MBPluginModule] = self.generateAllModulesHash()

    private func generateAllModules() -> [MBPluginModule] {
        return self.allPackages.flatMap { $0.allModules }
    }

    private func generateAllModulesHash() -> [String: MBPluginModule] {
        return Dictionary(self.allModules.map { ($0.name.lowercased(), $0) })
    }

    public func module(for name: String) -> MBPluginModule? {
        return self.allModulesHash[name.lowercased()]
    }

    private func dependencies(for name: String, result: inout [String]) {
        guard let module = self.module(for: name) else { return }
        for dp in module.dependencies.map(\.moduleName) {
            if result.contains(dp) {
                continue
            }
            result.append(dp)
            self.dependencies(for: dp, result: &result)
        }
    }

    public func dependencies(for name: String) -> [MBPluginModule] {
        var result = [String]()
        self.dependencies(for: name, result: &result)
        return result.compactMap { self.module(for: $0) }
    }

    // MARK: - Activated Plugin Modules
    public internal(set) var modules = Set<MBPluginModule>() {
        didSet {
            self.modulesHash = Dictionary(grouping: self.modules) { $0.package }
            self.packages = Array(modulesHash.keys)
        }
    }
    public private(set) var modulesHash = [MBPluginPackage: [MBPluginModule]]()
    public private(set) var packages: [MBPluginPackage] = []

    // MARK: - Search Plugins
    private func setNativeBundle(_ package: MBPluginPackage, in directory: String) {
        for module in package.allModules {
            if module.CLI == true, module.bundlePath == nil {
                let framework = directory.appending(pathComponent: module.relativeDir).appending(pathComponent: module.bundleName).cleanPath
                if framework.isDirectory {
                    UI.logLoad("[\(module.name)] Redirect Framework => \(framework)")
                    module.bundlePath = framework
                }
            }
        }
    }

    private func search(directory: String) -> [MBPluginPackage] {
        return UI.logLoad("- \(directory)") {
            return MBPluginPackage.search(directory: directory).values.sorted(by: \.name)
        }
    }

    private func addPacakge(_ package: MBPluginPackage, plugins: inout [String: [MBPluginPackage]]) {
        let name = package.name.lowercased()
        var v = plugins[name] ?? []
        v.insert(package, at: 0)
        plugins[name] = v
    }

    private func addPacakge(directory: String, plugins: inout [String: [MBPluginPackage]], block: (MBPluginPackage) -> Void) {
        search(directory: directory).forEach { package in
            block(package)
            self.addPacakge(package, plugins: &plugins)
        }
    }

    public func all() -> [MBPluginPackage] {
        let packages = UI.logLoad("Search Plugins:") { _all() }

        UI.logLoad("Found Plugins:", items: {
            return packages.sorted(by: \.name).map {
                "\($0.description)\n\($0.allModules.map { "  " + $0.moduleDescription }.joined(separator: "\n"))"
            }
        })

        return packages
    }

    private func _all() -> [MBPluginPackage] {
        var plugins: [String: [MBPluginPackage]] = [:]

        // Environment Plugin
        if let pluginPaths = try? MBProcess.shared.args.option(for: "plugin-paths", shift: true)?.split(separator: ":") {
            for path in pluginPaths {
                guard let package = MBPluginPackage.from(directory: String(path)) else {
                    continue
                }
                package.isInApplication = true
                self.addPacakge(package, plugins: &plugins)
            }

            // Development Plugin
            if let devRoot = MBProcess.shared.devRoot {
                search(directory: devRoot).forEach { p in
                    if let package = plugins[p.name.lowercased()]?.first {
                        setNativeBundle(package, in: devRoot.appending(pathComponent: "build").appending(pathComponent: package.name))
                    }
                }
            }
        } else {
            // User Plugin
            let homePluginPath = MBSetting.globalDir.appending(pathComponent: "plugins")

            self.addPacakge(directory: homePluginPath, plugins: &plugins) {
                $0.isInUserDirectory = true
            }

            // System Plugin
            let cmdPath = ProcessInfo.processInfo.arguments[0]
            let path = (cmdPath.destinationOfSymlink ?? cmdPath).appending(pathComponent: "../..").cleanPath
            var appPluginPaths = [path]

            if MBProcess.shared.devRoot != nil {
                let path2 = (cmdPath.destinationOfSymlink ?? cmdPath).appending(pathComponent: "../../..").cleanPath
                if !appPluginPaths.contains(path2) {
                    appPluginPaths.append(path2)
                }
            }

            let appPluginPath = Self.bundle.bundlePath.appending(pathComponent: "../..").cleanPath
            if !appPluginPaths.contains(appPluginPath) {
                appPluginPaths.append(appPluginPath)
            }

            for path in appPluginPaths {
                self.addPacakge(directory: path, plugins: &plugins) {
                    $0.isInApplication = true
                }
            }

            // Development Plugin
            if let devRoot = MBProcess.shared.devRoot {
                self.addPacakge(directory: devRoot, plugins: &plugins) {
                    $0.isUnderDevelopment = true
                    setNativeBundle($0, in: devRoot.appending(pathComponent: "build").appending(pathComponent: $0.name))
                }
            }
        }

        var resultPlugins = [String: MBPluginPackage]()
        plugins.forEach { (_, packages: [MBPluginPackage]) in
            let package = packages.first!
            package.merge(packages)
            resultPlugins[package.name] = package
        }
        if let core = resultPlugins["MBoxCore"] {
            core.module(named: "MBoxCore")?.bundlePath = self.bundle.bundlePath
        }

        return Array(resultPlugins.values)
    }
}

public func getModuleName(forClass: AnyClass) -> String {
    let bundle = Bundle(for: forClass)
    return bundle.name.deleteSuffix("Tests")
}

extension NSObject {
    public class var pluginModule: MBPluginModule? {
        let bundle = Bundle(for: self)
        let path = bundle.bundlePath
        return MBPluginManager.shared.modules.first { $0.bundlePath == path }
    }

    public class var pluginPackage: MBPluginPackage? {
        return self.pluginModule?.package
    }
}
