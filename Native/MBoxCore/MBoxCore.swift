//
//  MBoxCore.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/8/15.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
@_exported import SwifterSwift

var run = false

@objc(MBoxCore)
open class MBoxCore: NSObject, MBPluginProtocol {
    override init() {
        super.init()
        if !run {
            run = true
            runCommander()
        }
    }

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
        MBCommanderGroup.shared.addCommand(MBCommander.Plugin.Info.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Open.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Config.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Doc.self)
    }

    dynamic
    public static var version: String {
        var info = "CLI Core Version: \(self.bundle.shortVersion)"

        if let package = MBoxCore.pluginPackage {
            if let commitDate = package.commitDate {
                info.append(" (\(commitDate))")
            }
            if MBProcess.shared.verbose,
               let swiftVersion = package.swiftVersion {
                info.append(", Swift: v\(swiftVersion)")
            }
        }

        return info
    }

    dynamic
    public static var isBeta: Bool {
        return self.bundle.shortVersion.rangeOfCharacter(from: NSCharacterSet.letters) != nil
    }

    public static var latestVersion: String? = MBoxCore.queryLatestVersion()

    dynamic
    public static func queryLatestVersion() -> String? {
        return nil
    }
}

