//
//  MBPluginModule.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/9/14.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

public class MBPluginModule: MBCodableObject, MBYAMLProtocol {

    @Codable(key: "NAME")
    public var name: String

    public var nameWithGroup: String {
        guard let superModule = self.superModule else { return self.name }
        let subname = self.name.deletePrefix(superModule.name)
        return superModule.nameWithGroup + "/" + subname
    }

    public func isName(_ name: String) -> Bool {
        return self.name.lowercased() == name.lowercased()
    }

    @Codable(key: "DEPENDENCIES")
    public var _dependencies: [Dependency] = []

    @Codable(key: "FORWARD_DEPENDENCIES")
    public var forwardDependencies: [Dependency: String?] = [:]

    public var dependencies: [Dependency] {
        return (self._dependencies + Array(self.forwardDependencies.keys)).withoutDuplicates()
    }

    @Codable(key: "CLI")
    public var CLI: Bool = false

    @Codable(key: "GROUPS")
    public var groups: [String] = []

    @Codable(key: "REQUIRED")
    public var required: Bool = false

    @Codable(key: "LAUNCHERS")
    public var launchers: [String] = []

    public lazy var settingSchema: MBPluginSettingSchema? = .from(directory: path)

    public var path: String { return self.filePath!.deletingLastPathComponent }
    public var relativeDir: String {
        return self.path.relativePath(from: self.package.path)
    }

    @Codable(key: "MODULES")
    private var _modules: [String]
    public lazy var modules: [MBPluginModule] = {
        return self._modules.compactMap {
            guard let module = MBPluginModule.from(directory: self.path.appending(pathComponent: $0)) else { return nil }
            module.superModule = self
            module.package = self.package
            return module
        }
    }()

    public lazy var allSubModules: [MBPluginModule] = {
        return self.modules + self.modules.flatMap { $0.allSubModules }
    }()

    public private(set) weak var superModule: MBPluginModule?
    public weak var package: MBPluginPackage!

    public class func from(directory: String) -> MBPluginModule? {
        let path = directory.appending(pathComponent: "manifest.yml")
        guard let module: MBPluginModule = self.load(fromFile: path) else { return nil }
        return module
    }

    func createSubmodule(name: String, root: String) -> MBPluginModule {
        let filePath = root.appending(pathComponent: "manifest.yml")
        if let module = MBPluginModule.load(fromFile: filePath) {
            return module
        }
        var module = MBPluginModule()
        module.name = name.replacingOccurrences(of: "/", with: "")
        module.filePath = filePath
        module.superModule = self
        module.package = self.package
        _modules.append(String(name.split(separator: "/").last!))
        self.modules.append(module)
        return module
    }

    // MARK: - Native
    public lazy var bundleName: String = self.name.replacingOccurrences(of: ".", with: "").appending(pathExtension: "framework")

    public lazy var bundlePath: String? = {
        let path = self.path.appending(pathComponent: self.bundleName)
        if path.isExists { return path }
        return nil
    }()

    public lazy var mainBundle: Bundle? = {
        guard let path = self.bundlePath,
              path.isDirectory,
              let bundle = Bundle(path: path) else {
            return nil
        }
        return bundle
    }()

    public var mainClass: NSObject?

    @discardableResult
    public func load() -> Bool {
        if self.CLI != true { return true }
        guard let bundle = self.mainBundle else { return false }
        if !bundle.isLoaded {
            do {
                try bundle.loadAndReturnError()
                UI.logLoad("- \(self.name): `\(bundle.bundlePath)` SUCCESS".ANSI(.cyan))
            } catch {
                UI.log(info: "[!] Load Plugin Failed: \(self.name) \(error)".ANSI(.red), pip: .ERR)
                return false
            }
        }
        if mainClass == nil,
           let klass = bundle.principalClass as? NSObject.Type {
            mainClass = klass.init()
        }
        return true
    }

    public var isLoaded: Bool {
        guard let bundle = self.mainBundle else { return false }
        return bundle.isLoaded
    }

    public func unload() -> Bool {
        return self.mainBundle?.unload() ?? true
    }

    public func registerCommanders() {
        guard let klass = mainClass as? MBPluginProtocol else { return }
        klass.registerCommanders()
    }

    public static func == (lhs: MBPluginModule, rhs: MBPluginModule) -> Bool {
        return lhs.name == rhs.name && lhs.package == rhs.package
    }

    public var moduleDescription: String {
        return "\(self.name)\tFRAMEWORK: \(self.bundlePath?.relativePath(from: self.package.path) ?? "null")"
    }

    public override var description: String {
        return self.moduleDescription
    }

    // MARK: - Merge
    func merge(_ objects: [MBPluginModule]) {
        if self.CLI, self.bundlePath == nil {
            self.bundlePath = objects.firstMap { $0.bundlePath }
        }
    }
}
