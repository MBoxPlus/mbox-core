//
//  Open.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2019/10/25.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    open class Open: MBCommander {
        open class override var description: String? {
            return "Open GUI"
        }

        open override class var arguments: [Argument] {
            var args = super.arguments
            args << Argument("path", description: "Workspace Path", required: false)
            return args
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("logdir", description: "Open log folder")
            return flags
        }

        open override func setup() throws {
            try super.setup()
            self.path = self.shiftArgument("path")
            self.showLog = self.shiftFlag("logdir")
        }

        open override func run() throws {
            try super.run()
            if self.showLog {
                if let dir = UI.logger.verbFilePath?.deletingLastPathComponent {
                    self.open(path: dir)
                }
            } else {
                let path = pathToOpen(self.path)
                if let url = urlToOpen(path) {
                    self.open(url: url)
                }
            }
        }

        open var path: String?
        open var showLog: Bool = false

        dynamic
        open func pathToOpen(_ path: String?) -> String? {
            if var path = path?.expandingTildeInPath {
                if !path.isAbsolutePath {
                    path = FileManager.pwd.appending(pathComponent: path).cleanPath
                }
                return path
            }
            return path
        }

        dynamic
        open func urlToOpen(_ path: String?) -> URL? {
            var string = "mbox://open"
            if let p = path,
                let query = p.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                string.append("?path=\(query)")
            }
            return URL(string: string)
        }
    }
}
