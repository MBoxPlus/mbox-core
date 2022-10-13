//
//  MBPluginModule+History.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2022/3/4.
//  Copyright © 2022 bytedance. All rights reserved.
//

import Foundation

extension MBPluginModule {
    public class History: MBPluginHistory<MBPluginModule> {

        public static let filePath = MBSetting.globalDir.appending(pathComponent: "plugins.yml")

        public static var shared: History = History.load(fromFile: filePath)


        public override func latestVersion(for item: MBPluginModule) -> String {
            return item.package.version
        }

        public override func name(for item: MBPluginModule) -> String {
            return item.nameWithGroup
        }
    }
}
