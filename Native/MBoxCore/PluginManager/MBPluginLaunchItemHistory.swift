//
//  MBPluginLaunchItemHistory.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/7/23.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBPluginLaunchItem {
    open class History: MBPluginHistory<MBPluginLaunchItem> {

        public static let filePath = MBSetting.globalDir.appending(pathComponent: "launcher.yml")

        public static var shared: History = History.load(fromFile: filePath)

        public override func latestVersion(for item: MBPluginLaunchItem) -> String {
            return item.plugin.version
        }

        public override func name(for item: MBPluginLaunchItem) -> String {
            return item.fullName
        }
    }
}
