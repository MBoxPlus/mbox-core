//
//  LoadBundle.swift
//  MBoxCore
//
//  Created by Whirlwind on 2021/7/2.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

func getRealPath(_ path: String) -> String? {
    do {
        var targetPath: String
        let symlink = try FileManager.default.destinationOfSymbolicLink(atPath: path)
        if symlink.hasPrefix("/") {
            targetPath = symlink
        } else {
            targetPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(symlink)
        }
        return getRealPath(targetPath) ?? targetPath
    } catch {
        return nil
    }
}

func loadAndRun() {
    var path = ProcessInfo.processInfo.arguments[0]
    path = getRealPath(path) ?? path
    path = (path as NSString).deletingLastPathComponent
    path = (path as NSString).appendingPathComponent("MBoxCore.framework")
    loadAndRun(path)
}

func loadAndRun(_ path: String) {
    let path = getRealPath(path) ?? path
    guard let b = Bundle(path: path) else {
        print("[ERROR] Load bundle failed: \(path)")
        exit(254)
    }
    do {
        try b.loadAndReturnError()
    } catch {
        print("[ERROR] Load bundle failed: \(path)\n\t\(error)")
        exit(254)
    }
    let klass = b.principalClass as? NSObject.Type
    _ = klass!.init()
}

