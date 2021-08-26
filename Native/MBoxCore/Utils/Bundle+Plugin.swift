//
//  Bundle+Plugin.swift
//  MBox-PluginManager
//
//  Created by Whirlwind on 2018/8/21.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation
public extension Bundle {
    var name: String {
        return bundlePath.lastPathComponent.deletingPathExtension
    }

    var namespace: String {
        return (infoDictionary!["CFBundleExecutable"] as! String).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
    }

    func classWith(_ className: String) -> AnyClass? {
        return classNamed("\(namespace).\(className)")
    }
}
