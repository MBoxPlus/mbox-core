//
//  MBPluginManager+Launcher.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2020/7/22.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBPluginManager {

    public func launcherItem(for name: String) -> MBPluginLaunchItem? {
        let names = name.split(separator: "/")
        let pluginName = String(names.first!)
        let itemName = String(names.last!)
        guard let package = MBPluginManager.shared.package(for: pluginName) else {
            return nil
        }
        return package.launcherItems.first { $0.itemName == itemName }
    }

    public func launcherItem(for plugins: [MBPluginPackage], roles: [String] = []) -> [MBPluginLaunchItem] {
        let roles = roles.map { $0.lowercased() }
        var values = [MBPluginLaunchItem]()
        for dp in plugins {
            let requiredItems = dp.launcherItems.filter{ item in
                if !item.required { return false }
                if item.roles.isEmpty || roles.isEmpty {
                    return true
                }
                return !Set(item.roles.map { $0.lowercased() }).intersection(roles).isEmpty
            }
            values.append(contentsOf: requiredItems)
        }
        return values
    }

    public func requireInstallLauncher(for plugins: [MBPluginPackage]) -> [MBPluginPackage] {
        var todoItems = [MBPluginPackage]()
        let history = MBPluginLaunchItem.History.shared
        let items = self.launcherItem(for: plugins)
        for item in items {
            let status = history.status(for: item)
            if status != .ready, !todoItems.contains(item.plugin) {
                todoItems.append(item.plugin)
            }
        }
        return todoItems
    }

    public func installLauncherItem(_ item: MBPluginLaunchItem, type: MBPluginLaunchItem.LauncherType? = nil) -> Bool? {
        let history = MBPluginLaunchItem.History.shared
        let status = history.status(for: item)

        var scriptType: MBPluginLaunchItem.LauncherType
        if let type = type {
            scriptType = type
        } else {
            if status == .ready {
                return nil
            }
            scriptType = status == .requireInstall ? .install : .upgrade
        }

        guard let path = item.launcherPath(scriptType) ?? item.launcherPath(.install) else {
            MBPluginLaunchItem.History.upgrade(plugin: item.fullName, to: item.plugin.version)
            return true
        }


        return UI.section("[\(item.fullName!)]") {
            let code = item.runLauncherScript(path)
            if code == 0 {
                switch scriptType {
                case .check:
                    if (status == .requireInstall) {
                        MBPluginLaunchItem.History.upgrade(plugin: item.fullName, to: item.plugin.version)
                    }
                case .uninstall:
                    MBPluginLaunchItem.History.uninstall(plugin: item.fullName)
                default:
                    MBPluginLaunchItem.History.upgrade(plugin: item.fullName, to: item.plugin.version)
                }
                return true
            } else {
                UI.log(error: "[\(item.fullName!)] \(scriptType) failed!")
                return false
            }
        }
    }

    @discardableResult
    public func installLauncherItem(_ item: MBPluginLaunchItem,
                                    type: MBPluginLaunchItem.LauncherType? = nil,
                                    result: inout [String: Bool?]) -> Bool {
        if let s = result[item.fullName] {
            return s != false
        }
        var status = true
        if let dps = item.dependencies {
            for dp in dps {
                guard let item = self.launcherItem(for: dp) else {
                    UI.log(error: "Could not find the launcher `\(dp)!")
                    status = false
                    result[dp] = false
                    break
                }
                status = self.installLauncherItem(item, type: type, result: &result)
                if !status {
                    UI.log(error: "[\(item.fullName!)] Launch failed, due to the dependency failed: \(dp)")
                    status = false
                }
            }
        }
        if status {
            let s = self.installLauncherItem(item, type: type)
            result[item.fullName] = s
            return s != false
        } else {
            result[item.fullName] = status
            return status
        }
    }

    public func installLauncherItems(_ items: [MBPluginLaunchItem], type: MBPluginLaunchItem.LauncherType? = nil) -> (success: [String], failed: [String]) {
        var result = [String: Bool?]()
        for item in items {
            self.installLauncherItem(item, type: type, result: &result)
        }

        return (success: result.keys(forValue: true), result.keys(forValue: false))
    }
}
