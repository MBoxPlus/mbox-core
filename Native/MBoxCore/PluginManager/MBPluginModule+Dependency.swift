//
//  MBPluginModule+Dependency.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/12/27.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension MBPluginModule {
    public class Dependency: MBCodable, Hashable, Comparable, CustomStringConvertible {

        public var moduleName: String = ""
        public lazy var packageName: String = self.moduleName

        public required init() {
        }

        convenience init(_ name: String) {
            self.init()
            let names = name.split(separator: "/")
            self.packageName = String(names.first!)
            self.moduleName = String(names.last!)
            if !self.moduleName.hasPrefix(self.packageName) {
                self.moduleName = self.packageName + self.moduleName
            }
        }

        public static func load(fromObject object: Any) throws -> Self {
            if let v = object as? Self {
                return v
            }
            return Dependency.init(object as! String) as! Self
        }

        public func toCodableObject() -> Any? {
            if self.moduleName == self.packageName {
                return self.moduleName
            }
            return self.packageName + "/" + self.moduleName
        }

        public static func < (lhs: MBPluginModule.Dependency, rhs: MBPluginModule.Dependency) -> Bool {
            return lhs.moduleName < rhs.moduleName
        }

        public static func == (lhs: MBPluginModule.Dependency, rhs: MBPluginModule.Dependency) -> Bool {
            return lhs.moduleName == rhs.moduleName
        }

        public func hash(into hasher: inout Hasher) {
            self.moduleName.hash(into: &hasher)
        }

        public var description: String {
            return self.moduleName
        }
    }
}
