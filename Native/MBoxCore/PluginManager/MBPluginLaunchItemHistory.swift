//
//  MBPluginLaunchItemHistory.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2020/7/23.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBPluginLaunchItem {
    open class History: MBCodableObject, MBYAMLProtocol {

        public enum Status: String {
            case ready = "Ready"
            case requireInstall = "Install"
            case requireUpdate = "Upgrade"
        }

        public static let filePath = MBSetting.globalDir.appending(pathComponent: "launcher.yml")

        public static var shared: History {
            return History.load(fromFile: filePath)
        }

        open var all: [String: String] {
            return (self.dictionary as? [String: String]) ?? [:]
        }

        open func requireUpgrade(plugins: [MBPluginLaunchItem]) -> [MBPluginLaunchItem] {
            return plugins.filter {
                status(for: $0) != .ready
            }
        }

        open func status(for item: MBPluginLaunchItem) -> Status {
            if let oldVersion = self.all[item.fullName] {
                return oldVersion.isVersion(lessThan: item.plugin.version) ? .requireUpdate : .ready
            }
            return .requireInstall
        }

        open class func update(_ block: () -> ()) {
            var lock = pthread_rwlock_t()
            pthread_rwlock_init(&lock, nil)
            // Protecting write section:
            pthread_rwlock_wrlock(&lock)
            defer {
                // Write shared resource
                pthread_rwlock_unlock(&lock)

                // Clean up
                pthread_rwlock_destroy(&lock)
            }
            block()
        }

        open class func uninstall(plugin: String) {
            self.update() {
                let history = self.shared
                if history.dictionary.has(key: plugin) {
                    history.dictionary.removeValue(forKey: plugin)
                    history.save()
                }
            }
        }

        open class func upgrade(plugin: String, to version: String) {
            self.update() {
                let history = self.shared
                if let oldVersion = history.all[plugin],
                   oldVersion == version {
                    return
                }
                history.dictionary[plugin] = version
                history.save()
            }
        }
    }
}
