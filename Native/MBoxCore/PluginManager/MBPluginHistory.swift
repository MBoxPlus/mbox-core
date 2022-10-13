//
//  MBPluginHistory.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2022/3/4.
//  Copyright © 2022 bytedance. All rights reserved.
//

import Foundation

open class MBPluginHistory<T>: MBCodableObject, MBYAMLProtocol {

    public enum Status: String {
        case ready = "Ready"
        case requireInstall = "Install"
        case requireUpdate = "Upgrade"
    }

    open func version(for item: T) -> String? {
        return self.version(for: self.name(for: item))
    }

    open func version(for name: String) -> String? {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return self.dictionary[name] as? String
    }

    open func setVersion(_ version: String? = nil, for item: T) {
        self.setVersion(version ?? self.latestVersion(for: item), for: self.name(for: item))
    }

    open func setVersion(_ version: String?, for name: String) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        if let version = version {
            self.dictionary[name] = version
        } else {
            self.dictionary.removeValue(forKey: name)
        }
        self.save()
    }

    open func remove(item: T) {
        self.setVersion(nil, for: self.name(for: item))
    }

    open func remove(name: String) {
        self.setVersion(nil, for: name)
    }

    // for override
    open func latestVersion(for item: T) -> String {
        return ""
    }

    // for override
    open func name(for item: T) -> String {
        return ""
    }

    open func status(for name: String, latestVersion: String) -> (status: Status, version: String?) {
        guard let oldVersion = self.version(for: name) else {
            return (status: .requireInstall, version: nil)
        }
        if oldVersion.isVersion(lessThan: latestVersion) {
            return (status: .requireUpdate, version: oldVersion)
        } else {
            return (status: .ready, version: oldVersion)
        }
    }

    open func status(for item: T) -> (status: Status, version: String?) {
        return self.status(for: self.name(for: item),
                           latestVersion: self.latestVersion(for: item))
    }
}

