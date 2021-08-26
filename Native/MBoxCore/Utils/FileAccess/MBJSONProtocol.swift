//
//  MBJSONProtocol.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/28.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

public class MBJSONCoder: MBCoder {
    public static let shared = MBJSONCoder()

    public override func decode(string: String) throws -> Any? {
        let data = string.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data, options: [])
    }
    public override func encode(object: Any, sortedKeys: Bool, prettyPrinted: Bool) throws -> String {
        var options: JSONSerialization.WritingOptions = []
        if prettyPrinted {
            options.insert(.prettyPrinted)
        }
        if sortedKeys {
            options.insert(.sortedKeys)
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        return String(data: data, encoding: .utf8)!
    }
}

extension MBCoder {
    public static var json: MBCoder { return MBJSONCoder.shared }
}

public protocol MBJSONProtocol: MBFileProtocol {
}

public extension MBJSONProtocol {
    static var defaultCoder: MBCoder? {
        return MBJSONCoder.shared
    }
}
