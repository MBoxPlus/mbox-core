//
//  ZipCMD.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/9/9.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

open class ZipCMD: MBCMD {
    open func zip(path: String, targetPath: String, exclude names: [String] = [], quiet: Bool = true) -> Bool {
        var args = [targetPath, path]
        if !names.isEmpty {
            args.append(contentsOf: names.flatMap { ["-x", $0] })
        }
        if quiet {
            args.append("-q")
        }
        let string = args.map { $0.quoted }.joined(separator: " ")
        let cmd = "zip -ry \(string) -x '*.DS_Store'"
        return self.exec(cmd)
    }

    open func unzip(path: String, targetDir: String) -> Bool {
        let cmd = "ditto -x -k --sequesterRsrc --rsrc \(path.quoted) \(targetDir.quoted)"
        return self.exec(cmd)
    }
}
