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
            }
            self.launcherItemNames = self.shiftArguments("name")
            MBProcess.shared.requireSetupLauncher = false
            try super.setup()
        }

        open var launcherItemNames: [String] = []
        open var launcherItems: [MBPluginLaunchItem] = []
        open var script: MBPluginLaunchItem.LauncherType?
        open var roles: [String] = []

        open override func validate() throws {
            try super.validate()
            self.launcherItems = self.launcherItemNames.compactMap {
                MBPluginManager.shared.launcherItem(for: $0)
            }
            if self.launcherItems.isEmpty {
                self.launcherItems = MBPluginManager.shared.launcherItems(for: Array(MBPluginManager.shared.modules))
                if !self.roles.isEmpty {
                    let roles = self.roles.map { $0.lowercased() }
                    self.launcherItems = self.launcherItems.filter { item in
                        if item.roles.isEmpty { return true }
                        return !Set(item.roles.map { $0.lowercased() }).intersection(roles).isEmpty
                    }
                }
                for name in MBPluginLaunchItem.History.shared.dictionary.keys {
                    guard let item = MBPluginManager.shared.launcherItem(for: name) else {
                        MBPluginLaunchItem.History.shared.remove(name: name)
                        continue
                    }
                    if !self.launcherItems.contains(item) {
                        self.launcherItems.append(item)
                    }
                }
            }
        }

        open override func run() throws {
            try super.run()
            let result = MBPluginManager.shared.installLauncherItems(self.launcherItems, type: self.script)
            if MBProcess.shared.apiFormatter != .none {
                UI.log(api: ["success": result.success, "failed": result.failed])
            }
            UI.statusCode = result.failed.isEmpty ? 0 : 1
        }
    }
}
