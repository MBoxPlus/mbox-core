//
//  main.swift
//  MBoxCore
//
//  Created by Whirlwind on 2021/7/2.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

let args = ProcessInfo.processInfo.arguments
var devRoot: String?
if let index = args.firstIndex(of: "--dev-root") {
    devRoot = args[index + 1]
} else if let arg = args.first(where: { $0.hasPrefix("--dev-root=") }),
          let index = arg.firstIndex(of: "=") {
    devRoot = String(arg[arg.index(index, offsetBy: 1) ..< arg.endIndex])
} else if let path = ProcessInfo.processInfo.environment["MBOX_DEV_ROOT"] {
    devRoot = path
} else {
    let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mbox/config.json")
    if FileManager.default.fileExists(atPath: configPath.path),
       let data = try? Data(contentsOf: configPath),
       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
       let core = json["core"] as? [String: Any],
       let path = core["dev-root"] as? String {
        devRoot = path
    }
}

if let devRoot = (devRoot as NSString?)?.expandingTildeInPath {
    let path = (devRoot as NSString).appendingPathComponent("build/MBoxCore/MBoxCore.framework")
    if FileManager.default.fileExists(atPath: path) {
        loadAndRun(path)
    } else {
        loadAndRun()
    }
} else {
    print("[ERROR] require configuration. Use `mbox config core.dev-root [PATH] -g`.")
    exit(254)
}
