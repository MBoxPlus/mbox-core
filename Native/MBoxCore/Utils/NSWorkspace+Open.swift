//
//  NSWorkspace+Open.swift
//  MBoxCore
//
//  Created by lizhuoli on 2019/3/8.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation
import AppKit

extension NSWorkspace {
    @discardableResult
    func openFiles(_ fullPaths: [String], withApplication appName: String? = nil) -> Bool {
        if fullPaths.count == 0 { return false }
        var bundleIdentifier: String? = nil
        if let appName = appName, !appName.isEmpty {
            bundleIdentifier = NSWorkspace.bundleIdentifier(forApplication: appName) ?? appName
        }
        let fileURLs = fullPaths.map { URL(fileURLWithPath: $0) }
        return NSWorkspace.shared.open(fileURLs, withAppBundleIdentifier: bundleIdentifier, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
    }

    @discardableResult
    func openURLs(_ urls: [URL], withApplication appName: String? = nil) -> Bool {
        if urls.count == 0 { return false }
        var bundleIdentifier: String? = nil
        if let appName = appName, !appName.isEmpty {
            bundleIdentifier = NSWorkspace.bundleIdentifier(forApplication: appName)
        }
        return NSWorkspace.shared.open(urls, withAppBundleIdentifier: bundleIdentifier, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
    }

    static func bundleIdentifier(forApplication name: String) -> String? {
        if let path = NSWorkspace.shared.fullPath(forApplication: name),
            let bundle = Bundle(path: path) {
            return bundle.bundleIdentifier
        }
        return nil
    }
}
