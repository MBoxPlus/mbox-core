//
//  Open.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/10/25.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    open class Open: MBCommander {
        open class override var description: String? {
            return "Open specific path in MBox Environment"
        }

        dynamic
        open override class var arguments: [Argument] {
            var args = super.arguments
            args << Argument("paths", description: "Specific Path", required: false, plural: true)
            return args
        }

        dynamic
        open override class var flags: [Flag] {
            var flags = super.flags
            if Self.self == Open.self {
                flags << Flag("logdir", description: "Open log folder")
            }
            return flags
        }

        dynamic
        open override class func autocompletion(argv: ArgumentParser) -> [String] {
            return super.autocompletion(argv: argv)
        }

        open override func setup() throws {
            try super.setup()
            self.paths = self.shiftArguments("paths")
            self.showLog = self.shiftFlag("logdir")
        }

        open override func validate() throws {
            try super.validate()
            if !application.installed {
                throw UserError("The Application `\(self.application.name!)` maybe not installed.")
            }
        }

        dynamic
        open override func run() throws {
            try super.run()
            if self.showLog {
                guard let dir = UI.logger.filePath?.deletingLastPathComponent else {
                    throw RuntimeError("Log file not exists!")
                }
                self.paths = [dir]
            }

            for (path, app) in self.pathForApp(self.paths.map { (path: $0, app: nil) }) {
                self.open(path: path, in: app)
            }
        }

        dynamic
        open func pathForApp(_ paths: [(path: String, app: ExternalApp?)]) -> [(path: String, app: ExternalApp?)] {
            return paths
        }

        @discardableResult
        open func open(path: String, in app: ExternalApp?) -> Bool {
            let url: URL?
            if path.contains("://") {
                url = URL(string: path)
            } else {
                let path = self.expandPath(path)
                if !path.isExists { return false }
                url = URL(fileURLWithPath: path)
            }
            guard let aURL = url else { return false }
            return (app ?? self.application).open(url: aURL)
        }

        open var paths: [String] = []
        open var showLog: Bool = false

        dynamic
        open func expandPath(_ path: String, base: String? = nil) -> String {
            var path = path.expandingTildeInPath
            if !path.isAbsolutePath {
                path = (base ?? FileManager.pwd).appending(pathComponent: path).cleanPath
            }
            return path
        }

        open lazy var application: ExternalApp = getApp()

        dynamic
        open func getApp() -> ExternalApp {
            return ExternalApp.shared
        }
    }
}
