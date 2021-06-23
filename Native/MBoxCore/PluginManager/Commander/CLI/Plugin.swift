//
//  Plugin.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/8/21.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    open class Plugin: MBCommander {

        open class override var description: String? {
            return "Manage Plugins"
        }

        open override func run() throws {
            try super.run()
            if type(of: self) == MBCommander.Plugin.self {
                throw ArgumentError.invalidCommand(nil)
            }
        }
    }
}
