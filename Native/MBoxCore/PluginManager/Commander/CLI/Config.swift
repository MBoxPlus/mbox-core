//
//  Config.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/12/15.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    open class Config: MBCommander {

        public class Scope: NSObject {
            public static let Global = Scope.init("global")
            public static let RC = Scope.init("rc")
            public var name: String
            public init(_ name: String) {
                self.name = name
            }
            public override func isEqual(_ object: Any?) -> Bool {
                if let obj = object as? Scope {
                    return self.name == obj.name
                }
                if let obj = object as? String {
                    return self.name.lowercased() == obj.lowercased()
                }
                return super.isEqual(object)
            }
        }

        open class override var description: String? {
            return "Get/Set Default Configuration"
        }

        dynamic
        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("delete", flag: "d", description: "Delete configuration to restore default value.")
            flags << Flag("global", flag: "g", description: "Apply to global configuration.")
            flags << Flag("rc", description: "Apply to `~/.mboxrc`.")
            return flags
        }

        open override class var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("name", description: "Config Name", required: false, plural: false)
            arguments << Argument("value", description: "Config Value", required: false, plural: false)
            return arguments
        }

        open override class var extendHelpDescription: String? {
            var output = [String]()
            output.append("Settings:".ANSI(.underline))
            MBPluginManager.shared.packages.forEach { (package) in
                if let schema = package.settingSchema {
                    output.append("")
                    let settingID = schema.id ?? package.name
                    output.append("    [\(settingID.ANSI(.underline))]")
                    schema.properties?.forEach { (key, value) in
                        output.append("")
                        output.append("        \(key)".ANSI(.yellow))
                        if let type = value.type?.rawValue {
                            output.append("          Type: \(type)")
                        }
                        if let defaultValue = value.default?.valueDescription, !defaultValue.isEmpty {
                            output.append("          Default Value: \(defaultValue)")
                        }
                        if let desc = value.desc {
                            output.append("          Description: \(desc)")
                        }
                        output.append("          Example: `mbox config \(settingID).\(key) [VALUE]`")
                    }
                }
            }
            return output.joined(separator: "\n")
        }

        dynamic
        open override func setup() throws {
            self.isDelete = self.shiftFlag("delete")
            if self.shiftFlag("global") {
                self.scope = .Global
            } else if self.shiftFlag("rc") {
                self.scope = .RC
            }
            self.name = self.shiftArgument("name")
            self.value = self.shiftArguments("value")
            try super.setup()
        }

        open override func validate() throws {
            try super.validate()
            if self.isDelete && self.isEdit {
                throw ArgumentError.conflict("`--delete` is not allowed for configure mode.")
            }
        }

        open var name: String?
        open var isDelete: Bool = false
        open var value: [String] = []
        open var scope: Scope = .Global
        open var isEdit: Bool {
            return self.name?.isEmpty == false && self.value.isEmpty == false
        }

        dynamic
        open var setting: MBCodableObject & MBFileProtocol {
            if self.scope.isEqual("rc")  {
                return MBEnvironment.shared
            }
            return MBSetting.global
        }

        open override func run() throws {
            try super.run()
            if self.isEdit {
                let setting = try configure(name: self.name!)
                saveSetting(setting)
                try show(name: self.name!)
            } else if self.isDelete {
                let setting = try delete(name: self.name!)
                saveSetting(setting)
            } else if let name = self.name {
                try show(name: name)
            } else {
                try show()
            }
        }

        open func schema(for name: String) -> MBPluginSettingSchema? {
            if self.scope.isEqual("rc") {
                for plugin in MBPluginManager.shared.packages {
                    for (key, value) in plugin.settingSchema?.properties ?? [:] {
                        if key.lowercased() == name.lowercased() {
                            return value
                        }
                    }
                }
                return nil
            }
            let paths = name.components(separatedBy: ".")
            guard let firstName = paths.first, let plugin = MBPluginManager.shared.packages.first(where: { $0.settingSchema?.id == firstName }) else {
                return nil
            }
            let settingSchema = plugin.settingSchema!
            let setting = self.setting
            var subSettingSchema: MBPluginSettingSchema? = settingSchema
            var subPath = firstName
            for (index, path) in paths.enumerated() {
                if index > 0 {
                    subSettingSchema = subSettingSchema?.properties?[path]
                }
                if subSettingSchema == nil {
                    return nil
                } else {
                    if subSettingSchema?.type == .object {
                        let v = setting.dictionary[subPath]
                        if !(v is MBCodableObject) && !(v is [String: Any]) {
                            let dict = Dictionary<String, Any>()
                            setting.setValue(dict, forPath: subPath)
                        }
                    } else {
                        break
                    }
                    subPath = subPath.appending(path)
                }
            }
            return subSettingSchema
        }

        open func show() throws {
            let hash: [String: Any] = setting.toCodableObject() as! [String : Any]
            let string = try hash.toString(coder: .json, sortedKeys: true, prettyPrinted: true)
            UI.log(info: string)
        }

        open func show(name: String) throws {
            guard let settingSchema = schema(for: self.name!) else {
                throw UserError("The key path `\(self.name!)` is invalid.")
            }
            let name = settingSchema.fullName
            guard let value = setting.dictionary.valueForKeyPath(name) ?? settingSchema.default else {
                return
            }
            var string: String
            if let v = value as? Dictionary<String, Any> {
                string = try v.toString(coder: .json, sortedKeys: true, prettyPrinted: true)
            } else {
                if let boolValue = (value as? NSNumber)?.boolValue, settingSchema.type == MBPluginSettingSchema.MBPluginSettingSchemaTypeName.boolean {
                    string = "\(boolValue)"
                } else {
                    string = "\(value)".description
                }
            }
            UI.log(info: "\(name): \(string)")
        }

        open func delete(name: String) throws -> MBCodableObject & MBFileProtocol {
            guard let schema = schema(for: name) else {
                throw UserError("The key path `\(name)` is invalid.")
            }
            let setting = self.setting
            setting.dictionary.removeValue(forKeyPath: schema.fullName)
            return setting
        }

        open func configure(name: String) throws -> MBCodableObject & MBFileProtocol {
            guard let settingSchema = schema(for: name) else {
                throw UserError("The key path `\(name)` is invalid.")
            }
            let setting = self.setting
            let name = settingSchema.fullName
            if !settingSchema.scopes.isEmpty, !settingSchema.scopes.contains(where: { self.scope.isEqual($0)
            }) {
                throw UserError("The key path `\(name)` is not supported in \(self.scope.name) setting.")
            }
            switch settingSchema.type {
            case .string:
                setting.setValue(value.first!.toCodableObject() as? MBCodable, forPath: name)
            case .number:
                setting.setValue(NumberFormatter().number(from: value.first!).toCodableObject() as? MBCodable, forPath: self.name!)
            case .boolean:
                setting.setValue(value.first!.bool.toCodableObject() as? MBCodable, forPath: name)
            case .object:
                if let object = value.first!.toJSONDictionary()?.toCodableObject() as? MBCodable {
                    setting.setValue(object, forPath: name)
                }
            case .array:
                setting.dictionary.setValue(value, forKeyPath: name)
            default:
                throw UserError("The schema type: \(settingSchema.type as? MBPluginSettingSchemaType ?? "nil") is not supported.")
            }
            return setting
        }

        open func saveSetting(_ setting: MBFileProtocol) {
            setting.save()
        }
    }
}
