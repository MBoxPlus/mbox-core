//
//  SystemInfo.swift
//  MBoxCore
//
//  Created by Yao Li on 2021/12/13.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation
import MachO

public class SystemInfo {
    public static var shared = SystemInfo()
    
    public enum SystemArchType: String {
        case x86_64 = "x86_64"
        case arm64 = "arm64"
    }

    public lazy var architecture: SystemArchType = {
        let info = NXGetLocalArchInfo()
        let arch = String(cString: info!.pointee.description)
        if arch.lowercased().contains("x86-64") {
            return .x86_64
        } else if arch.lowercased().contains("arm64") {
            return .arm64
        }
        return .x86_64
    }()

}
