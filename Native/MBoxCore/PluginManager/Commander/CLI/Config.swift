//
//  Config.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2019/12/15.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    open class Config: MBCommander {

        open class override var description: String? {
            return "Get/Set Default Configuration"
        }

        dynamic
        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("delete", flag: "d", description: "Delete configuration to restore default value.")
            flags << Flag("global", flag: "g", description: "Apply to global configuration.")
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
            UI.activedPlugins.forEach { (package) in
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
            self.isGlobal = self.shiftFlag("global")
            self.name = self.shiftArgument("name")
            self.value = self.shiftArgument("value")
            try super.setup()
        }

        open override func validate() throws {
            try super.validate()
            if self.isDelete && self.isEdit {
                throw ArgumentError.conflict("`--delete` is not allowed for configure mode.")
            }
        }

        open var name: String?
        open var value: String?
        open var isDelete: Bool = false
        open var isGlobal: Bool = false
        open var isEdit: Bool {
            return self.name?.isEmpty == false && self.value?.isEmpty == false
        }

        dynamic
        open var setting: MBSetting {
            return MBSetting.global
        }

        open override func run() throws {
            try super.run()
            if self.isEdit {
                try configure()
            } else if self.isDelete {
                try delete()
            } else if let name = self.name {
                try show(name: name)
            } else {
                try show()
            }
        }

        open func propertyName(for name: String) -> String {
            return name;
//            return name.split(separator: ".").map { string in
//                let name = String(string).convertCamelCased().dropFirst()
//                return "\(string.first!)\(name)"
//            }.joined(separator: ".")
        }

        open func checkSetting(for name: String) -> MBPluginSettingSchema? {
            let paths = propertyName(for: name).components(separatedBy: ".")
            guard let firstName = paths.first, let plugin = UI.activedPlugins.first(where: { $0.settingSchema?.id == firstName }) else {
                return nil
            }
            let settingSchema = plugin.settingSchema!
            var setting: MBCodableObject;
            if !self.isGlobal {
                setting = self.setting
            } else {
                setting = MBSetting.global
            }
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
            guard let settingSchema = checkSetting(for: self.name!) else {
                throw UserError("The key path `\(self.name!)` is invalid.")
            }
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
            UI.log(info: "\(self.name!): \(string)")
        }

        open func delete() throws {
            if checkSetting(for: self.name!) == nil {
                throw UserError("The key path `\(self.name!)` is invalid.")
            }
            let setting = self.isGlobal ? MBSetting.global : self.setting
            setting.dictionary.removeValue(forKey: self.name!)
            saveSetting(setting)
        }

        open func configure() throws {
            guard let settingSchema = checkSetting(for: self.name!) else {
                throw UserError("The key path `\(self.name!)` is invalid.")
            }
            guard let value = self.value else {
                throw UserError("The value is nil.")
            }
            var setting: MBSetting;
            if !self.isGlobal {
                setting = self.setting
            } else {
                setting = MBSetting.global
            }
            if setting == MBSetting.global &&
                settingSchema.global != true {
                throw UserError("The key path `\(self.name!)` is not supported in global setting.")
            }
            switch settingSchema.type {
            case .string:
                setting.setValue(value.toCodableObject() as? MBCodable, forPath: self.name!)
            case .number:
                setting.setValue(NumberFormatter().number(from: value).toCodableObject() as? MBCodable, forPath: self.name!)
            case .boolean:
                setting.setValue(value.bool.toCodableObject() as? MBCodable, forPath: self.name!)
            case .object:
                if let object = value.toJSONDictionary()?.toCodableObject() as? MBCodable {
                    setting.setValue(object, forPath: self.name!)
                }
            case .array:
                if let array = value.toJSONArray() {
                    setting.dictionary.setValue(array, forKeyPath: self.name!)
                }
            default:
                throw UserError("The schema type: \(settingSchema.type as? MBPluginSettingSchemaType ?? "nil") is not supported.")
            }

            saveSetting(setting)
            try show(name: self.name!)
        }

        open func saveSetting(_ setting: MBSetting) {
            setting.save()
        }
    }
}
