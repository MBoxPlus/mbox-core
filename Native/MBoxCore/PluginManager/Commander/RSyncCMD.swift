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
                let matches = try? self.outputString.match(regex: "rsync +version +([^ ]+)") {
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

    open func exec(sourceDirs: [String],
                   targetDir: String,
                   progress: Bool = false,
                   options: [String]) -> Bool {
        var params = options
        if progress {
            if greater(version: "3.1.0") {
                params << "--info=progress2"
                params << "--info=name0"
            } else {
                params << "--progress"
                params << "--stats"
            }
        }
        params << sourceDirs.map { "\($0)/".quoted }
        params << targetDir.quoted
        if !targetDir.isExists {
            try? FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true, attributes: nil)
        }
        return exec(params.joined(separator: " "))
    }

    open func exec(sourceDir: String,
                   targetDir: String,
                   delete: Bool = false,
                   progress: Bool = false,
                   excludes: [String] = []) -> Bool {
        var params = ["-avr"]
        var excludes = excludes
        excludes << ".DS_Store"
        params << excludes.map { "--exclude='\($0)'" }
        if delete {
            params.append("--delete")
            params.append("--delete-excluded")
        }
        return self.exec(sourceDirs: [sourceDir], targetDir: targetDir, progress: progress, options: params)
    }
}
