//
//  Bundle+InfoDictionary.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/6/6.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
extension Bundle {
    public static var app: Bundle? {
        var path = ProcessInfo.processInfo.arguments[0].destinationOfSymlink ?? main.bundlePath
        while true {
            if path.pathExtension.lowercased() == "app" {
                return Bundle(path: path)
            }
            path = path.deletingLastPathComponent
            if path == "/" || path.isEmpty {
                return nil
            }
        }
    }

    public var shortVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as! String
    }
}
