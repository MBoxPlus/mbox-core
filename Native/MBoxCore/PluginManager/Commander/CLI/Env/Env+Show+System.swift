//
//  Env+Show+System.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/10/11.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Env {
    open class System: MBCommanderEnv {
        public static var supportedAPI: [APIType] {
            return [.api, .none]
        }

        public static var title: String {
            return "system"
        }

        required public init() {
        }

        public func APIData() throws -> Any?  {
            return [
                "User Name": MBUser.current?.nickname ?? "",
                "User Email": MBUser.current?.email ?? "",
                "System Version": ProcessInfo.processInfo.operatingSystemVersion.description,
                "MBox Version": MBoxCore.version
            ]
        }

        public func textRows() throws -> [Row]? {
            return [
                ["User Name:", MBUser.current?.nickname ?? ""],
                ["User Email:", MBUser.current?.email ?? ""],
                ["OS Version:", ProcessInfo.processInfo.operatingSystemVersion.description],
                ["MBox Version:", MBoxCore.version]
            ].map { Row(columns: $0) }
        }
    }
}
