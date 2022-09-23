//
//  Info.swift
//  MBoxCore
//
//  Created by Whirlwind on 2022/8/19.
//  Copyright © 2022 bytedance. All rights reserved.
//

import Foundation
extension MBCommander.Plugin {
    open class Info: MBCommander.Env {
        open class override var description: String? {
            return "Show Plugin Information"
        }

        open override class var arguments: [Argument] {
            var args = super.arguments
            args << Argument("name", description: "Names of Plugin", required: true, plural: true)
            return args
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags.removeAll { $0.name == "only" }
            return flags
        }

        open override func setup() throws {
            try super.setup()
            self.only = ["plugins"]
            self.pluginNames = self.shiftArguments("name")
            Env.Plugins.showTitle = false
            Env.Plugins.indent = false
        }

        open var pluginNames: [String] = []

        open lazy var packages: [MBPluginPackage] = {
            self.pluginNames.compactMap { name in
                if let package = MBPluginManager.shared.package(for: name) {
                    return package
                }
                UI.log(warn: "[\(name)] Could not find plugin.")
                return nil
            }
        }()

        public override func instance(for section: MBCommanderEnv.Type) -> MBCommanderEnv {
            return Env.Plugins(packages: self.packages)
        }
    }
}
