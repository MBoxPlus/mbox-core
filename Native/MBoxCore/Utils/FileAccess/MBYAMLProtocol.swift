//
//  MBYAMLProtocol.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/23.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation
import Yams

extension NSDictionary: NodeRepresentable {
    /// This value's `Node` representation.
    public func represented() throws -> Node {
        return try (self as Dictionary).represented()
    }
}

extension NSArray: NodeRepresentable {
    /// This value's `Node` representation.
    public func represented() throws -> Node {
        return try (self as Array).represented()
    }
}

extension NSString: ScalarRepresentable {
    /// This value's `Node.scalar` representation.
    public func represented() -> Node.Scalar {
        return (self as String).represented()
    }
}

extension NSNumber: ScalarRepresentable {
    public func represented() -> Node.Scalar {
        switch CFGetTypeID(self as CFTypeRef) {
        case CFBooleanGetTypeID():
            return self.boolValue.represented()
        case CFNumberGetTypeID():
            switch CFNumberGetType(self as CFNumber) {
            case .sInt8Type:
                return self.int8Value.represented()
            case .sInt16Type:
                return self.int16Value.represented()
            case .sInt32Type:
                return self.int32Value.represented()
            case .sInt64Type:
                return self.int64Value.represented()
            case .doubleType:
                return self.doubleValue.represented()
            default:
                return self.intValue.represented()
            }
        default:
            return self.intValue.represented()
        }
    }
}

public class MBYAMLCoder: MBCoder {
    public static let shared = MBYAMLCoder()

    public override func decode(string: String) throws -> Any? {
        return try Yams.load(yaml: string)
    }

    public override func encode(object: Any, sortedKeys: Bool, prettyPrinted: Bool) -> String {
        let string = (try? Yams.dump(object: object, sortKeys: sortedKeys)) ?? ""
        return string.replace(regex: "\\\\u([0-9A-F]{4})") { match in
            let groupRange = match.range(at: 1)
            let groupString = string[groupRange]
            let code = UInt32(groupString, radix: 16)!
            return "\(UnicodeScalar(code)!)"
        }
    }
}

extension MBCoder {
    public static var yaml: MBCoder { return MBYAMLCoder.shared }
}

public protocol MBYAMLProtocol: MBFileProtocol {
}

public extension MBYAMLProtocol {
    static var defaultCoder: MBCoder? {
        return MBYAMLCoder.shared
    }
}
