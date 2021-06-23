//
//  MBoxCore.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/8/15.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

@objc(MBoxCore)
open class MBoxCore: NSObject, MBPluginProtocol {

    dynamic
    public func registerCommanders() {
        MBCommanderGroup.shared.addCommand(MBCommander.Env.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Setup.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.List.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Launch.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Uninstall.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Enable.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Disable.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Open.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Config.self)
    }

    public static var version: String {
        var info = ""
        if let app = Bundle.app {
            info.append("GUI Core Version: \(app.shortVersion), ")
        }
        info.append("CLI Core Version: \(self.bundle.shortVersion)")

        if let package = MBoxCore.pluginPackage,
            let commitDate = package.commitDate {
            info.append(" (\(commitDate))")
        }
        return info
    }

    public static var latestVersion: String? = MBoxCore.queryLatestVersion()

    dynamic
    public static func queryLatestVersion() -> String? {
        return nil
    }
}

