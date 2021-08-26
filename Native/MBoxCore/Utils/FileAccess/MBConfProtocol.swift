//
//  MBConfProtocol.swift
//  MBoxCore
//
//  Created by Whirlwind on 2021/6/24.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

public class MBConfCoder: MBCoder {
    public static let shared = MBConfCoder()

    public override func decode(string: String) throws -> Any? {
        var dict = [String: String]()
        for line: Substring in string.splitLines() {
            let value: [Substring] = line.split(separator:"=", maxSplits:1, omittingEmptySubsequences:true)
            if value.count != 2 { continue }
            dict[String(value.first!)] = String(value[1])
        }
        return dict
    }

    public override func encode(object: Any, sortedKeys: Bool, prettyPrinted: Bool) throws -> String {
        guard let dict = object as? [String: Any] else {
            throw RuntimeError("Invalid format `\(type(of: object))`.")
        }
        var values = [String]()
        var keys = Array(dict.keys)
        if sortedKeys {
            keys = keys.sorted()
        }
        for key in keys {
            if let value = dict[key] as? String {
                values << "\(key)=\(value)"
            }
        }
        return values.joined(separator: "\n")
    }
}

extension MBCoder {
    public static var conf: MBCoder { return MBConfCoder.shared }
}

public protocol MBConfProtocol: MBFileProtocol {
}

public extension MBConfProtocol {
    static var defaultCoder: MBCoder? {
        return .conf
    }
}
