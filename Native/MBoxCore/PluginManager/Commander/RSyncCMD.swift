//
//  RSyncCMD.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/9/28.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

open class RSyncCMD: MBCMD {
    public required init(useTTY: Bool? = nil) {
        super.init(useTTY: useTTY)
        self.bin = "rsync"
    }

    public static var version: String?

    open var version: String? {
        if Self.version == nil {
            if exec("--version"),
                let matches = try? self.outputString.match("rsync +version +([^ ]+)") {
                let version = matches.first?[1]
                UI.log(verbose: "Rsync Version: \(version ?? "unknown")")
                Self.version = version
            }
        }
        return Self.version
    }

    open func greater(version: String) -> Bool {
        if let installedVersion = self.version,
            version.compare(installedVersion, options: .numeric) != .orderedDescending {
            return true
        } else {
            return false
        }
    }

    open func exec(sourceDir: String, targetDir: String, delete: Bool = false, ignoreExisting: Bool = true, progress: Bool = false, exclude: [String] = []) -> Bool {
        var params = ["-avr"]
        var excludes = exclude
        excludes << ".DS_Store"
        params << excludes.map { "--exclude=\($0)" }
        if delete {
            params.append("--delete")
        }
        if ignoreExisting {
            params.append("--ignore-existing")
        }
        if progress {
            if greater(version: "3.1.0") {
                params << "--info=progress2"
                params << "--info=name0"
            } else {
                params << "--progress"
                params << "--stats"
            }
        }
        params.append("\(sourceDir)/".quoted)
        params.append(targetDir.quoted)
        if !targetDir.isExists {
            try? FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true, attributes: nil)
        }
        return exec(params.joined(separator: " "))
    }

    @discardableResult
    open func exec(sourceFiles: [String], targetDir: String, removeSourceFiles: Bool = false) -> Bool {
        var params = ["-avr", "--exclude=.DS_Store", "--delete"]
        if removeSourceFiles {
            params << "--remove-source-files"
        }
        let files = sourceFiles.filter { file -> Bool in
            var path = file.expandingTildeInPath
            if !path.hasPrefix("/") {
                path = (self.workingDirectory ?? FileManager.pwd).appending(pathComponent: path)
            }
            return path.isExists
        }
        if files.isEmpty {
            try? FileManager.default.removeItem(atPath: targetDir)
            return true
        }

        params.append(contentsOf: files.map { $0.quoted } )
        params << "\(targetDir)/".quoted

        if !targetDir.isDirectory {
            try? FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true, attributes: nil)
        }
        return exec(params.joined(separator: " "))
    }
}
