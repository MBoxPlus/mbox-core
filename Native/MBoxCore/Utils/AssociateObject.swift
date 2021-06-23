//
//  AssociateObject.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/24.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation

public func associatedObject<T>(base: AnyObject,
                                key: UnsafePointer<UInt8>,
                                initialiser: () -> T)
    -> T {
        if let associated = objc_getAssociatedObject(base, key) as? T {
            return associated
        }
        let associated = initialiser()
        objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
        return associated
}

public func associatedObject<T>(base: AnyObject,
                                key: UnsafePointer<UInt8>,
                                initialiser: () -> T?)
    -> T? {
        if let associated = objc_getAssociatedObject(base, key) as? T {
            return associated
        }
        let associated = initialiser()
        objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
        return associated
}

public func associatedObject<T>(base: AnyObject,
                                key: UnsafePointer<UInt8>,
                                defaultValue: T)
    -> T {
        if let associated = objc_getAssociatedObject(base, key) as? T {
            return associated
        }
        objc_setAssociatedObject(base, key, defaultValue, .OBJC_ASSOCIATION_RETAIN)
        return defaultValue
}

public func associatedObject<T>(base: AnyObject,
                                key: UnsafePointer<UInt8>)
    -> T? {
        if let v = objc_getAssociatedObject(base, key) as? T? {
            return v
        }
        return nil
}

public func associateObject<T>(base: AnyObject,
                               key: UnsafePointer<UInt8>,
                               value: T) {
    objc_setAssociatedObject(base, key, value, .OBJC_ASSOCIATION_RETAIN)
}

private var associatedObjectKey: UInt8 = 0
extension NSObject {
    open var objectTag: AnyObject? {
        set {
            objc_setAssociatedObject(self, &associatedObjectKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
        get {
            return objc_getAssociatedObject(self, &associatedObjectKey) as AnyObject
        }
    }
}
