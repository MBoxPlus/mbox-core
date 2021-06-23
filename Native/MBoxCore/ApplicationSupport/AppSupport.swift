//
//  ApplicationSupport.swift
//  MBoxCore
//
//  Created by Yao Li on 2020/12/30.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

open class AppSupport {
    public static let rootDir = FileManager.supportDirectory

    public static var shared: AppSupport {
        return AppSupport()
    }

    public lazy var config: MBConfig? = {
        return MBConfig.load(fromFile: MBConfig.configPath)
    }()

    public class MBConfig: MBCodableObject, MBJSONProtocol {
        public static let configPath = AppSupport.rootDir.appending(pathComponent: "config.json")

        @Codable
        public var settings: Settings?

        public class Settings: MBCodableObject {
            @Codable
            public var subscribeToBetaChannel: Bool?
        }
    }
}
