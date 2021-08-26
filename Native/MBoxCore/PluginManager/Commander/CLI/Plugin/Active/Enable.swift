//
//  Enable.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/11/17.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Plugin {
    open class Enable: Activate {
        open class override var description: String? {
            return "Enable plugins by name."
        }

        open override func run() throws {
            self.isScopeCheckNeeded = true

            try super.run()
        }

        open override func handle(_ setting: MBSetting) throws {
            try super.handle(setting)
            for name in self.names {
                if try setting.addPlugin(name) {
                    UI.log(info: "Enable plugin `\(name)` success!")
                } else {
                    UI.log(warn: "Plugin `\(name)` enabled!")
                }
            }
        }
    }
}
