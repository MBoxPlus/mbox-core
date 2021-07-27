//
//  Env.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/9/22.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    @objc(MBCommanderEnv)
    open class Env: MBCommander {

        open override class var options: [Option] {
            var options = super.options
            options << Option("only", description: "Only show information.", values: self.sections())
            return options
        }

        open class override var description: String? {
            return "Show MBox Environment"
        }

        dynamic
        open override func setup() throws {
            self.mode = self.shiftOption("only")
            try super.setup()
        }

        open var mode: String?

        dynamic
        open override func run() throws {
            try super.run()
            var sections = Self.sections()
            if let mode = self.mode?.uppercased() {
                sections = sections.filter { mode == $0.uppercased() }
            }
            for section in sections {
                try show(section: section)
                UI.log(info: "")
            }
        }

        dynamic
        open class func sections() -> [String] {
            return ["SYSTEM", "PLUGINS"]
        }

        dynamic
        open func show(section: String) throws {
            if section == "SYSTEM" {
                try UI.log(info: "[SYSTEM]:") {
                    try showSystem()
                }
            } else if section == "PLUGINS" {
                try UI.log(info: "[PLUGINS]:") {
                    try showPlugins()
                }
            }
        }

        open func showSystem() throws {
            let info = """
            User Name: \(MBUser.current?.nickname ?? "")
            User Email: \(MBUser.current?.email ?? "")
            System \(ProcessInfo.processInfo.operatingSystemVersionString)
            MBox \(MBoxCore.version)
            """
            UI.log(info: info)
        }

        open func showPlugins() throws {
            let packages = MBPluginManager.shared.packages.sorted(by: \.name)
            if UI.apiFormatter == .plain {
                UI.log(api: packages.map { $0.path })
                return
            }
            var values = [Any]()
            for package in packages {
                var required = [String]()
                for alias in package.names {
                    if let pluginDesc = UI.plugins.first(where: { (key, value) -> Bool in
                        return key.lowercased() == alias.lowercased()
                    })?.value  {
                        required.append(contentsOf: pluginDesc.compactMap(\.requiredBy))
                    }
                }
                let depended = packages.filter { $0.dependencies?.contains(package.name) == true }.map(\.name)
                if UI.apiFormatter == .none {
                    values << package.detailDescription(required: required, depended: depended)
                } else {
                    var dict = package.dictionary
                    if !required.isEmpty {
                        dict["REQUIRED_BY"] = required
                        dict["DEPENDED_ON"] = depended
                    }
                    dict["PATH"] = package.path
                    values << dict
                }
            }
            if UI.apiFormatter == .json {
                UI.log(api: values)
            } else {
                UI.log(info: values.map { $0 as! String }.joined(separator: "\n"))
            }
        }
    }
}

