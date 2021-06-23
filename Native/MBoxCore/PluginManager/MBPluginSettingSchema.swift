//
//  MBPluginSettingSchema.swift
//  MBoxCore
//
//  Created by Yao Li on 2020/4/29.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

/// MBPluginSettingSchema is based on JSON Schema draft-07
/// Reference:  http://json-schema.org/draft-07/schema#
public final class MBPluginSettingSchema: MBCodableObject, MBJSONProtocol {
    public enum MBPluginSettingSchemaTypeName: String {
        case object = "object"
        case array = "array"
        case string = "string"
        case number = "number"
        case boolean = "boolean"
    }

    @Codable
    public var id: String?

    public var type: MBPluginSettingSchemaTypeName? {
        get {
            if let value = self.dictionary["type"] as? String {
                return MBPluginSettingSchemaTypeName(rawValue: value)
            } else {
                return nil
            }
        }
        set {
            self.dictionary["type"] = newValue?.rawValue
        }
    }

    @Codable
    public var title: String?

    @Codable(key: "description")
    public var desc: String?

    public var `default`: MBPluginSettingSchemaType? {
        guard let defaultValue = self.dictionary["default"] else {
            return nil
        }
        switch type {
            case .string:
                return defaultValue as? String
            case .number:
                self.dictionary["default"] = 1
                guard let defaultValueString = defaultValue as? String else {
                    return nil
                }
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal;
                return formatter.number(from: defaultValueString)
            case .boolean:
                return defaultValue as? Bool
            case .object:
                return defaultValue as? MBPluginSettingSchema
            case .array:
                return defaultValue as? Array<Any>
            default:
                return nil
        }
    }

    @Codable
    public var examples: [MBPluginSettingSchemaType]?

    @Codable
    public var properties: [String: MBPluginSettingSchema]?

    @Codable
    public var items: MBPluginSettingSchemaItems?

    @Codable
    public var `enum`: [MBPluginSettingSchemaType]?

    @Codable
    public var global: Bool?

    public var path: String!

    public class func from(directory: String) -> MBPluginSettingSchema? {
        let path = directory.appending(pathComponent: "setting.schema.json")
        let schema: MBPluginSettingSchema? = self.load(fromFile: path)
        schema?.path = path
        return schema
    }
}

public protocol MBPluginSettingSchemaItems { }

public protocol MBPluginSettingSchemaType {
    func toDescriptionString() -> String?
}

public extension MBPluginSettingSchemaType {
    var valueDescription: String {
        return toDescriptionString() ?? ""
    }

    func toDescriptionString() -> String? {
        return nil
    }
}

extension NSNumber: MBPluginSettingSchemaType {
    public func toDescriptionString() -> String? {
        return self.description
    }
}
extension MBPluginSettingSchema: MBPluginSettingSchemaType { }
extension String: MBPluginSettingSchemaType {
    public func toDescriptionString() -> String? {
        return self.description
    }
}
extension Bool: MBPluginSettingSchemaType {
    public func toDescriptionString() -> String? {
        return self ? "true" : "false"
    }
}
extension Array: MBPluginSettingSchemaType { }

extension MBPluginSettingSchema: MBPluginSettingSchemaItems { }
extension Array: MBPluginSettingSchemaItems { }





