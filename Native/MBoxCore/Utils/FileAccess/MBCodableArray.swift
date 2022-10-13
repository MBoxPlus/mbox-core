//
//  MBCodableArray.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/1/13.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

open class MBCodableArray<T: MBCodable>: NSObject, MBCodable {

    public required override init() {
        super.init()
    }

    public required init(array: [T]) {
        super.init()
        self.array = array
    }

    public static func load(fromObject object: Any) throws -> Self {
        guard let array = object as? [Any] else {
            throw NSError(domain: "Convert Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Type mismatch \(self): \(object)"])
        }
        let item = try self.init(array: array.map { try T.load(fromObject: $0) })
        return item
    }

    open lazy var array: [T] = []

    open func toCodableObject() -> Any? {
        return self.array.toCodableObject()
    }
}
