//
//  MBPluginLaunchItem.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/7/21.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

public final class MBPluginLaunchItem: MBCodableObject {

    public enum LauncherType: String, CaseIterable {
        case check = "check"
        case install = "install"
        case uninstall = "uninstall"
        case upgrade = "upgrade"
    }

    public var fullName: String!
    public var pluginName: String!
    public var itemName: String!
    public lazy var path: String = plugin.launcherDir!.appending(pathComponent: self.itemName)

    public weak var plugin: MBPluginPackage!

    @Codable
    public var required: Bool = false

    @Codable
    public var dependencies: [String]?

    @Codable
    public var roles: [String] = []

    public func setName(_ name: String, in plugin: MBPluginPackage) {
        self.plugin = plugin
        self.pluginName = plugin.name
        self.itemName = name
        self.fullName = "\(pluginName!)/\(itemName!)"
    }

    public func launcherPath(_ type: LauncherType) -> String? {
        return self.path.subFiles.first { $0.lastPathComponent.deletingPathExtension == type.rawValue }
    }

    public func runLauncherScript(_ scriptPath: String) -> Int32 {
        let cmd = MBCMD()
        cmd.showOutput = true
        cmd.workingDirectory = scriptPath.deletingLastPathComponent
        cmd.env["MBOX_CORE_LAUNCHER"] = MBoxCore.pluginPackage!.launcherDir
        cmd.env["MBOX_PLUGIN_PATH"] = self.plugin.path
        cmd.env["MBOX_PLUGIN_NAME"] = self.pluginName
        return cmd.exec("sh ./\(scriptPath.lastPathComponent.quoted)")
    }

    public override func isEqual(_ object: Any?) -> Bool {
        if super.isEqual(object) {
            return true
        }
        guard let other = object as? MBPluginLaunchItem else {
            return false
        }
        return self.fullName.lowercased() == other.fullName.lowercased()
    }
}
