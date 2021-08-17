//
//  MBPluginPackageBundle.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2020/9/7.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension MBPluginPackage {
    public class PluginBundle: NSObject {
        init(name: String, path: String, package: MBPluginPackage) {
            self.name = name
            self.path = path
            self.package = package
        }
        public let path: String
        public let name: String
        public weak var package: MBPluginPackage?
        public var dependencies: [String]? {
            return self.package?.dependencies(for: self.name)
        }

        public lazy var mainBundle: Bundle? = {
            guard let bundle = Bundle(path: path) else {
                return nil
            }
            return bundle
        }()

        public var mainClass: MBPluginProtocol?

        @discardableResult
        public func load() -> Bool {
            guard let bundle = self.mainBundle else { return false }
            if !bundle.isLoaded {
                do {
                    if ProcessInfo.processInfo.environment["DYLD_PRINT_LIBRARIES"] == "1" {
                        UI.log(info: "Load Plugin: \(self.package!.path!)", pip: .ERR)
                    }
                    try bundle.loadAndReturnError()
                } catch {
                    UI.log(info: "Load Plugin `\(self.package!.name)` Error: \(error)", pip: .ERR)
                    return false
                }
            }
            if mainClass == nil,
               let klass = bundle.principalClass as? NSObject.Type,
               klass.self is MBPluginProtocol.Type,
               let instance = klass.init() as? MBPluginProtocol {
                mainClass = instance
            }
            return true
        }

        public var isLoaded: Bool {
            guard let bundle = self.mainBundle else { return false }
            return bundle.isLoaded
        }

        public func unload() -> Bool {
            return self.mainBundle?.unload() ?? true
        }

        public func registerCommanders() {
            mainClass?.registerCommanders()
        }

        public static func == (lhs: MBPluginPackage.PluginBundle, rhs: MBPluginPackage.PluginBundle) -> Bool {
            return lhs.name == rhs.name && lhs.package == rhs.package
        }

        public override var description: String {
            return "<MBPluginPackage.PluginBundle \(self.package!.name)/\(self.name) (\(self.path))>"
        }
    }
}
