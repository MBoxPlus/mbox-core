//
//  List.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/8/21.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Plugin {
    open class List: Plugin {

        open class override var description: String? {
            return "List all plugins"
        }

        open override func run() throws {
            try super.run()
            if MBProcess.shared.apiFormatter == .none {
                outputPlain()
            } else {
                outputData()
            }
        }

        dynamic
        open var packages: [MBPluginPackage] {
            return Array(MBPluginManager.shared.allPackages)
        }

        open func outputPlain() {
            for package in self.packages.sorted(by: \.name) {
                UI.log(info: package.packageDetailDescription().joined(separator: "\n"))
                UI.log(info: "")
            }
        }

        open func outputData() {
            let data = Dictionary<String, Any>(uniqueKeysWithValues: self.packages.map { package in
                return (package.name, package.dictionary)
            })
            UI.log(api: data.toCodableObject()!)
        }
    }
}
