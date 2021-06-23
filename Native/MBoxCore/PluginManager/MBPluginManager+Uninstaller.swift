//
//  MBPluginManager+Uninstaller.swift
//  MBoxCore
//
//  Created by Yao Li on 2020/11/18.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBPluginManager {
    @discardableResult
    public func uninstall(name: String) throws -> MBPluginPackage? {
        if let plugin = self.package(for: name) {
            guard !plugin.isUnderDevelopment else {
                throw UserError("Cannot uninstall the plugins which are under development. Plugin package is at `\(plugin.path!)`")
            }

            guard plugin.isInUserDirectory else {
                throw UserError("Cannot uninstall the built-in plugins. Plugin package is at `\(plugin.path!)`")
            }
            try FileManager.default.removeItem(atPath: plugin.path)
            return plugin
        }
        throw UserError("Cannot found the plugin [\(name)].")
    }

}

