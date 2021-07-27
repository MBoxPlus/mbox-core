//
//  MBEnvironment.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/6/24.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation
open class MBEnvironment: MBCodableObject, MBConfProtocol {
    public static let filePath = MBSetting.globalDir.appending(pathComponent: "environment.conf")
    public static let shared: MBEnvironment = MBEnvironment.load(fromFile: filePath)
}
