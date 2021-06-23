//
//  MBRootCommandeer.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/7/6.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
import Then

extension MBCommander {
    open class MBox: MBCommander {
        open override class var name: String? {
            return "mbox"
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("version", description: "Show version")
            return flags
        }

        open override func setup(argv: ArgumentParser) throws {
            try super.setup(argv: argv)
            self.version = self.shiftFlag("version")
        }

        public var version: Bool = false

        open override func run() throws {
            try super.run()
            if version {
                let info = MBoxCore.version
                UI.log(info: info)
                return
            }
            throw ArgumentError.invalidCommand(nil)
        }
    }
}
