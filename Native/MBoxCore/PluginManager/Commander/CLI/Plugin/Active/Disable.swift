//
//  Disable.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2020/11/17.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Plugin {
    open class Disable: Activate {
        open class override var description: String? {
            return "Disable plugins by name."
        }

        open override func handle(_ setting: MBSetting) throws {
            try super.handle(setting)
            for name in self.names {
                if setting.removePlugin(name) {
                    UI.log(info: "Disable plugin `\(name)` success!")
                } else {
                    UI.log(warn: "Plugin `\(name)` disabled!")
                }
            }
        }
    }
}
