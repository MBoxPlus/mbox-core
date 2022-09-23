//
//  Env+Show+Plugins.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/10/11.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension MBPluginModule {
    public func toAPIObject() -> Any? {
        var value = self.toCodableObject() as! [String: Any]
        if !self.modules.isEmpty {
            value["MODULES"] = self.modules.toCodableObject()
        }
        return value
    }
}

extension MBCommander.Env {
    open class Plugins: MBCommanderEnv {
        public static var supportedAPI: [MBCommander.Env.APIType] {
            return [.api, .none, .plain]
        }

        public static var title: String {
            return "plugins"
        }

        public static var showTitle: Bool = true
        public static var indent: Bool = true

        required public init() {
            self.packages = MBPluginManager.shared.packages
        }

        required public init(packages: [MBPluginPackage]) {
            self.packages = packages
        }

        public var packages: [MBPluginPackage]

        public func APIData() throws -> Any?  {
            return self.packages.map { $0.toAPIObject() }
        }

        public func plainData() throws -> [String]? {
            return self.packages.sorted(by: \.name).map { $0.path }
        }

        public func textRows() throws -> [Row]? {
            return MBPluginManager.shared.modulesHash
                .filter { self.packages.contains($0.key) }
                .sorted(by: \.key)
                .flatMap { (package, modules) in
                    package.packageDetailDescription(for: modules.sorted(by: \.name))
                }.map { Row(column: $0) }
        }
    }
}

extension MBPluginPackage {

    dynamic
    public func packagePathDescription() -> [String] {
        var desc = [String]()
        desc << "PATH: \t\(self.path)"
        if let dir = self.launcherDir, dir.isExists {
            desc << "LAUNCHER:\t\(dir)"
        }
        if let dir = self.resourcesDir, dir.isExists {
            desc << "RESOURCE:\t\(dir)"
        }
        return desc
    }

    dynamic
    public func packageDetailDescription(for modules: [MBPluginModule]? = nil) -> [String] {
        let nameDesc = (self.name.ANSI(.yellow) + " " + "(\(self.version))".ANSI(.magenta) + ":")
        var desc = [String]()
        if let authors = self.authors, !authors.isEmpty {
            if authors.count == 1 {
                desc << "AUTHOR:\t\(authors.first!)"
            } else {
                desc << "AUTHORS:"
                desc << authors.map { "  - \($0)" }
            }
        }
        if let publisher = self.publisher {
            desc << "PUBLISHER:\t\(publisher)"
        }
        if let homepage = self.homepage {
            desc << "HOMEPAGE:\t\(homepage)"
        }
        desc << self.packagePathDescription()
        if let commitID = self.commitID {
            desc << "COMMIT:\t\(commitID)"
        }
        if let commitDate = self.commitDate {
            desc << "DATE:\t\(commitDate)"
        }
        let modules = modules ?? self.allModules
        if !modules.isEmpty {
            desc << "MODULES:"
            desc << modules.flatMap { module -> [String] in
                var descs = module.moduleDetailDescription()
                let name = descs.removeFirst()
                descs = descs.map { "  \($0)" }
                return ["- \(name)"] + descs
            }.map { "  \($0)" }
        }
        return [nameDesc] + desc.map { "  \($0)" }
    }
}

extension MBPluginModule {

    dynamic
    public func modulePathDescription() -> [String] {
        var desc = [String]()
        desc << "PATH:\t\(self.path)"
        if let dir = self.bundlePath {
            desc << "CLI:\t\(dir)"
        }
        return desc
    }

    dynamic
    public func moduleDetailDescription() -> [String] {
        var name = "NAME:\t\(self.name)"
        if self.required {
            name << " (Required)".ANSI(.black, bright: true)
        }
        var desc = [name]
        desc << self.modulePathDescription()

        if !self.launchers.isEmpty {
            desc << "LAUNCHERS:"
            for name in self.launchers {
                desc << "  - \(name)"
            }
        }

        let fowardDps = self.forwardDependencies.map { $0.key }
        let dps = self.dependencies
        if !dps.isEmpty {
            desc << "DEPENDENCIES:"
            for dp in dps.sorted() {
                var dpDesc = "  - \(dp)"
                if fowardDps.contains(dp) {
                    dpDesc << " (Forward)".ANSI(.black, bright: true)
                }
                desc << dpDesc
            }
        }

        var requiredBy = [String]()
        if let pluginDescriptions = MBProcess.shared.cachedPlugins.first(where: { self.isName($0.key) })?.value {
            requiredBy << pluginDescriptions.compactMap { $0.requiredBy }
        }
        if !requiredBy.isEmpty {
            desc << "REQUIRED BY:"
            desc << requiredBy.map { "  - \($0)"}
        }
        return desc
    }
}
