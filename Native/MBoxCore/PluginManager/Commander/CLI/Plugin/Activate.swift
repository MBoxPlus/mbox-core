//
//  Activate.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/11/17.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Plugin {
    open class Activate: Plugin {
        open override class var arguments: [Argument] {
            return [Argument("name", description: "Plugin names", required: false, plural: true)]
        }

        dynamic
        open override class var options: [Option] {
            return super.options
        }

        dynamic
        open override class var flags: [Flag] {
            return super.flags
        }

        dynamic
        open override func setup() throws {
            try super.setup()
            self.names = self.shiftArguments("name")
        }

        open override func run() throws {
            try super.run()
            guard let settings = self.settings else {
                throw UserError("Failed to \(Self.fullName.split(separator: ".").last ?? "operate") the plugin(s).")
            }

            if settings.isEmpty {
                throw UserError("Could not find the setting file.")
            }
            for setting in settings {
                try UI.log(info: "Modify file: `\(setting.filePath!)`") {
                    try self.handle(setting)
                    if !setting.save() {
                        throw RuntimeError("Save config file failed: \(setting.filePath!)")
                    }
                }
            }

            UI.reloadPlugins()
            try self.setupLauncher(force: true)
        }

        open func handle(_ setting: MBSetting) throws {

        }

        open var names: [String] = []
        open var isScopeCheckNeeded: Bool = false

        open lazy var settings: [MBSetting]? = {
            return fetchSetting()
        }()

        dynamic
        open func fetchSetting() -> [MBSetting]? {
            if self.isScopeCheckNeeded {
                for name in self.names {
                    if let package = MBPluginManager.shared.package(for: MBSetting.pluginName(for: name)) {
                        if package.scope != .APPLICATION {
                            UI.log(error: "Plugin `\(name)` cannot be enabled/disabled in `Application` scope")
                            return nil
                        }
                    }
                }
            }

            return [MBSetting.global]
        }
    }
}
