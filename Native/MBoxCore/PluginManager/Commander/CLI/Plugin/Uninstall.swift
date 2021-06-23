//
//  Uninstall.swift
//  MBoxCore
//
//  Created by Yao Li on 2020/11/18.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Plugin {
    open class Uninstall: Plugin {
        open class override var description: String? {
            return "Uninstall Plugins"
        }

        open override class var arguments: [Argument] {
            return [Argument("name", description: "Names of Plugins", required: false, plural: true)]
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("all", description: "Uninstall all plugins in user directory")
            return flags
        }

        open override func setup() throws {
            self.all = self.shiftFlag("all")
            self.pluginNames = self.shiftArguments("name")
            if !self.all && self.pluginNames.count == 0 {
                throw UserError("Name of plugin is required or use `--all` flag to uninstall all plugins.")
            }
            try super.setup()
        }

        open var pluginNames: [String] = []
        open var all: Bool = false

        open override func run() throws {
            try super.run()
            try self.pluginNames.forEach { name in
                if let plugin = try MBPluginManager.shared.uninstall(name: name) {
                    UI.log(info: "Plugin `\(plugin.name)` (\(plugin.version)) was successfully uninstalled.".ANSI(.green))
                }
            }
        }
    }
}
