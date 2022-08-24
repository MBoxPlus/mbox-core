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

            MBProcess.shared.reloadPlugins()
            try self.setupLauncher(force: true)
        }

        open func handle(_ setting: MBSetting) throws {

        }

        open var names: [String] = []

        open lazy var settings: [MBSetting]? = {
            return fetchSetting()
        }()

        dynamic
        open func fetchSetting() -> [MBSetting]? {
            return [MBSetting.global]
        }
    }
}
