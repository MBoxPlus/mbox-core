//
//  MBYAMLProtocol.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/23.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation
import Yams

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
        return (try? Yams.dump(object: object, sortKeys: sortedKeys)) ?? ""
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
