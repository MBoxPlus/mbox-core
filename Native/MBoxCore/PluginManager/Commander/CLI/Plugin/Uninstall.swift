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
            return "\(self) Plugins"
        }

        open override class var arguments: [Argument] {
            return [Argument("name", description: "Names of Plugin", required: true, plural: true)]
        }

        open override func setup() throws {
            self.pluginNames = self.shiftArguments("name")
            try super.setup()
        }

        open var pluginNames: [String] = []

        open override func run() throws {
            try super.run()
            if self.pluginNames.isEmpty {
                UI.log(info: "There is no plugin needed to \(Self.self).")
            } else {
                for name in self.pluginNames {
                    try self.handlePlugin(name: name)
                }
            }
        }

        open func handlePlugin(name: String) throws {
            if let package = try MBPluginManager.shared.uninstall(name: name) {
                MBPluginManager.shared.allPackages.removeAll(package)
                UI.log(info: "Plugin `\(package.name)` (\(package.version)) was successfully uninstalled.".ANSI(.green))
            }
        }
    }
}
