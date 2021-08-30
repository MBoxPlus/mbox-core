//
//  Setup.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/8/23.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    open class Setup: MBCommander {

        open class override var description: String? {
            return "Setup Command Line Tool"
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("zsh", description: "Install autocompletion support for zsh")
            return flags
        }

        open override class var options: [Option] {
            var options = super.options
            options << Option("bin-dir", description: "Output the executable bin to specific directory.")
            return options
        }

        open override func setup() throws {
            self.zsh = self.shiftFlag("zsh")
            self.binDir = self.shiftOption("bin-dir")
            try super.setup()
            UI.requireSetupLauncher = false
        }

        open var zsh: Bool = false
        open var binDir: String?

        open override func run() throws {
            try super.run()
            try self.installCommandLine()
            if self.zsh {
                try self.installAutoCompletion()
            }
        }

        open func installCommandLine() throws {
            if let binDir = self.binDir {
                try UI.section("Install mbox in `\(binDir)`") {
                    try MBCMD.installCommandLine(binDir: binDir)
                }
            }
            try UI.section("Source mbox function in `~/.profile`") {
                try MBCMD.installCommandLineAlias()
            }
            UI.log(info: "")
            UI.log(info: "Setup Completed.")
        }

        open func installAutoCompletion() throws {
            try UI.section("Install autocompletion support for zsh") {
                try MBCMD.installZSHAutocompletion()
                UI.log(warn: "If you want to enable the autocompletion support, please add the `mbox` to `plugins` in the `~/.zshrc`.")
            }
        }
    }
}
