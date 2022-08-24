//
//  MBPluginManager+PluginLoader.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/10/9.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension MBPluginManager {

    public func resolveModules(_ names: [String], loadedModules: Set<MBPluginModule>) -> Set<MBPluginModule> {
        let resolver = Resolver { dependency in
            if let module = self.module(for: dependency.name) {
                UI.logLoad("Query dependency `\(dependency)` -> \([PinnedVersion(module.package.version)])")
                return .success([PinnedVersion(module.package.version)])
            }
            UI.logLoad("Could not find \(dependency)")
            return .failure(.unsatisfiableDependencyList([dependency.name]))
        } dependenciesForDependency: { (dependency, pinnedVersion) in
            guard let module = self.module(for: dependency.name) else {
                UI.logLoad("Could not find \(dependency) \(pinnedVersion)")
                return .failure(.taggedVersionNotFound(dependency))
            }
            let dps = module.dependencies.map { (Dependency($0.moduleName, rootName: $0.packageName), VersionSpecifier.any) }
            UI.logLoad("Query dependencies for `\(dependency)`(\(pinnedVersion)) -> \(dps)")
            return .success(Dictionary(dps))
        } forwardDependenciesForDependency: { (dependency, pinnedVersion) in
            guard let module = self.module(for: dependency.name) else {
                UI.logLoad("Could not find \(dependency) \(pinnedVersion)")
                return .failure(.taggedVersionNotFound(dependency))
            }
            let dps = module.forwardDependencies.map { (Dependency($0.key.moduleName, rootName: $0.key.packageName), VersionSpecifier.any) }
            if !dps.isEmpty {
                UI.logLoad("Query forward dependencies for `\(dependency)`(\(pinnedVersion)) -> \(dps)")
            }
            return .success(Dictionary(dps))
        } resolvedGitReference: {_,_ in
            return .failure(.internalError(description: "Not support"))
        }
        let result = resolver.resolve(dependencies: Dictionary(names.map { (Dependency($0), VersionSpecifier.any)}),
                                      lastResolved: Dictionary(loadedModules.map { (Dependency($0.name, rootName: $0.package.name), PinnedVersion($0.package.version))}),
                                      dependenciesToUpdate: nil)
        guard let dps = result.value else {
            return Set()
        }
        return Set(dps.compactMap { self.module(for: $0.key.name) })
    }

    @discardableResult
    public func load(module: MBPluginModule,
                     loadedModules: inout Set<MBPluginModule>,
                     failedModules: inout Set<MBPluginModule>) -> Bool {
        if loadedModules.contains(module) {
            return true
        }
        if failedModules.contains(module) {
            return false
        }
        var success = true
        for dependency in module.dependencies {
            guard let module = self.module(for: dependency.moduleName) else { continue }
            if !self.load(module: module, loadedModules: &loadedModules, failedModules: &failedModules) {
                success = false
                break
            }
        }
        if success {
            success = module.load()
        }
        if success {
            loadedModules.insert(module)
        } else {
            failedModules.insert(module)
        }
        return success
    }

    public func loadAll() {
        let allModules = self.allModules
        UI.logLoad("Load Modules:") {
            var loadedModules = Set<MBPluginModule>()
            var failedModules = Set<MBPluginModule>()

            UI.logLoad("Load System Required Plugins") {
                while true {
                    var requiredModules = Set(allModules.filter {
                        $0.package.isInApplication && $0.required
                    })
                    requiredModules.subtract(loadedModules)
                    requiredModules.subtract(failedModules)
                    if requiredModules.isEmpty { break }

                    let count = loadedModules.count

                    self.tryLoad(modules: { requiredModules },
                                 loadedModules: &loadedModules,
                                 failedModules: &failedModules)

                    if count == loadedModules.count { break }
                }
            }

            self.modules = loadedModules
            self.installPlugin()

            var loop = true
            var times = 0
            while loop {
                times += 1
                UI.logLoad("Load User Plugins (Loop \(times))") {
                    let plugins = MBProcess.shared.plugins.keys
                    if plugins.isEmpty {
                        UI.logLoad("No Plugins to Load.")
                        return
                    }
                    UI.logLoad("Query Plugins:", items: { return Array(plugins).sorted() })
                    var modules = plugins.compactMap { self.module(for:$0) }
                    if modules.isEmpty {
                        UI.logLoad("No Modules to Load.")
                        return
                    }
                    modules.append(contentsOf: allModules.filter { $0.required })

                    var todoModules = UI.logLoad("[Resolver]") {
                        return self.resolveModules(modules.map { $0.name }.withoutDuplicates(), loadedModules: loadedModules)
                    }
                    todoModules.subtract(loadedModules)
                    todoModules.subtract(failedModules)
                    if todoModules.isEmpty {
                        UI.logLoad("All Modules Loaded.")
                        loop = false
                        return
                    }
                    UI.logLoad("Query Modules:", items: { return todoModules.map(\.name).sorted() })

                    for module in todoModules {
                        load(module: module, loadedModules: &loadedModules, failedModules: &failedModules)
                    }

                    if failedModules.count > 0 {
                        UI.log(warn: "Load Plugin Failed:", items: failedModules.map(\.name), summary: false)
                    }
                }
            }

            self.modules = loadedModules
            self.installPlugin()

            MBProcess.shared.cachedPlugins = MBProcess.shared.plugins
        }
    }

    dynamic
    public func loadLoop(loadedModules: inout Set<MBPluginModule>,
                         failedModules: inout Set<MBPluginModule>) {
        var todoModules = Set(self.allPackages.flatMap(\.allModules))
        var loop = 0
        while true {
            if todoModules.isEmpty {
                break
            }

            loop += 1
            UI.logLoad("# Loop \(loop)")

            let count = loadedModules.count

            let requiredModules = todoModules.filter { $0.required }
            if !requiredModules.isEmpty {
                    self.tryLoad(modules: { todoModules.filter { $0.required } },
                                 loadedModules: &loadedModules,
                                 failedModules: &failedModules)
                    todoModules.subtract(loadedModules)
                    todoModules.subtract(failedModules)
            }

            if count == loadedModules.count {
                break
            }
        }
    }

    public func tryLoad(modules: () -> Set<MBPluginModule>,
                        loadedModules: inout Set<MBPluginModule>,
                        failedModules: inout Set<MBPluginModule>) {
        while true {
            let todoModules = modules()
                .subtracting(loadedModules)
                .subtracting(failedModules)
                .filter { module in
                    if module.forwardDependencies.isEmpty {
                        return true
                    }
                    return self.isSatisfied(module.forwardDependencies,
                                            in: loadedModules)
                }
            if todoModules.isEmpty { break }
            for module in todoModules.sorted(by: \.name) {
                load(module: module, loadedModules: &loadedModules, failedModules: &failedModules)
            }
        }
    }

    private func isSatisfied(_ constraints: [MBPluginModule.Dependency: String?], in modules: Set<MBPluginModule>) -> Bool {
        for (dp, _) in constraints {
            if !modules.contains(where: { $0.name.lowercased() == dp.moduleName.lowercased() }) {
                return false
            }
        }
        return true
    }

    dynamic
    public func additionalPluginPackages() -> [String: [MBSetting.PluginDescriptor]] {
        return [:]
    }

    dynamic
    public func registerCommander() {
        for module in self.modules {
            module.registerCommanders()
        }
    }

    public func installPlugin() {
        let history = MBPluginModule.History.shared
        let modules = self.modules.map {
            ($0, history.status(for: $0))
        }.filter {
            $1.status != .ready
        }
        if modules.isEmpty {
            return
        }
        UI.log(verbose: "Check Plugin Upgrade", pip: .ERR) {
            for (module, status) in modules {
                UI.log(verbose: "\(status.status.rawValue) \(module.name) v\(module.package!.version) \(status.version == nil ? "" : "from `\(status.version!)`")") {
                    if let klass = module.mainClass as? MBPluginMigrateProtocol {
                        try? klass.installPlugin(from: status.version)
                    }
                    history.setVersion(for: module)
                }
            }
        }
    }
}
