//
//  Launch.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/3/11.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Plugin {
    open class Launch: Plugin {

        open class override var description: String? {
            return "Run a plugin launcher"
        }

        open override class var arguments: [Argument] {
            return [Argument("name", description: "Launcher names", plural: true)]
        }

        open override class var options: [Option] {
            var options = super.options
            options << Option("script", description: "Run the script name", values: MBPluginLaunchItem.LauncherType.allCases.map { $0.rawValue })
            options << Option("role", description: "Set current role, defaults to environment variable `MBOX_ROLES`")
            return options
        }

        open override func setup() throws {
            if let scriptName: String = self.shiftOption("script") {
                guard let script = MBPluginLaunchItem.LauncherType.allCases.first(where: { $0.rawValue.lowercased() == scriptName.lowercased() }) else {
                    throw ArgumentError.invalidValue(value: scriptName, argument: "script")
                }
                self.script = script
            }
            if let roles: [String] = self.shiftOptions("role") {
                self.roles = roles
            } else if let roles = ProcessInfo.processInfo.environment["MBOX_ROLES"]?.split(separator: ",").map({ String($0) }) {
                self.roles = roles
            }
            self.launcherItemNames = self.shiftArguments("name")
            UI.requireSetupLauncher = false
            try super.setup()
        }

        open var launcherItemNames: [String] = []
        open var launcherItems: [MBPluginLaunchItem] = []
        open var script: MBPluginLaunchItem.LauncherType?
        open var roles: [String] = []

        open override func validate() throws {
            try super.validate()
            self.launcherItems = try self.launcherItemNames.flatMap {
                try self.launcherItem(for: $0)
            }
            if self.launcherItems.isEmpty {
                let plugins = Array(MBPluginManager.shared.packages)
                self.launcherItems = MBPluginManager.shared.launcherItem(for: plugins, roles: self.roles)
                for name in MBPluginLaunchItem.History.shared.all.keys {
                    let names = name.split(separator: "/")
                    let pluginName = String(names.first!)
                    guard plugins.contains(where: { $0.isPlugin(pluginName) }) else {
                        continue
                    }
                    guard let items = try? self.launcherItem(for: name) else {
                        MBPluginLaunchItem.History.uninstall(plugin: name)
                        continue
                    }
                    for item in items {
                        if !self.launcherItems.contains(item) {
                            self.launcherItems.append(item)
                        }
                    }
                }
            }
        }

        open func launcherItem(for name: String) throws -> [MBPluginLaunchItem] {
            let names = name.split(separator: "/")
            let pluginName = String(names.first!)
            guard let plugin = MBPluginManager.shared.package(for: pluginName) else {
                throw ArgumentError.invalidValue(value: name, argument: "name")
            }
            if plugin.hasLauncher != true {
                throw UserError("[\(plugin.name)] No launcher in the plugin.")
            }
            if names.count == 1 {
                return plugin.launcherItems
            } else {
                let itemName = String(names.last!)
                guard let item = plugin.launcherItems.first(where: { $0.itemName.lowercased() == itemName.lowercased() }) else {
                    throw ArgumentError.invalidValue(value: name, argument: "name")
                }
                return [item]
            }
        }

        open override func run() throws {
            try super.run()
            let result = MBPluginManager.shared.installLauncherItems(self.launcherItems, type: self.script)
            if UI.apiFormatter != .none {
                UI.log(api: ["success": result.success, "failed": result.failed])
            }
            UI.statusCode = result.failed.isEmpty ? 0 : 1
        }
    }
}
