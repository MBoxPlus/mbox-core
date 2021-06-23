//
//  AssociateWeakObject.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/11/28.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

private class MBAssociatedWeakWrapper<T: NSObject>: NSObject {
    weak var object: T?
}

public func associatedWeakObject<T: NSObject>(base: AnyObject,
                                              key: UnsafePointer<UInt8>,
                                              initialiser: () -> T?)
    -> T? {
        let wrapper = objc_getAssociatedObject(base, key) as? MBAssociatedWeakWrapper ?? MBAssociatedWeakWrapper()
        if let associated = wrapper.object as? T {
            return associated
        }
        wrapper.object = initialiser()
        objc_setAssociatedObject(base, key, wrapper, .OBJC_ASSOCIATION_RETAIN)
        return wrapper.object as? T
}

public func associatedWeakObject<T: NSObject>(base: AnyObject,
                                              key: UnsafePointer<UInt8>)
    -> T? {
        if let wrapper = objc_getAssociatedObject(base, key) as? MBAssociatedWeakWrapper {
            return wrapper.object as? T
        }
        return nil
}

public func associateWeakObject<T: NSObject>(base: AnyObject,
                                             key: UnsafePointer<UInt8>,
                                             value: T?) {
    if let value = value {
        let wrapper = objc_getAssociatedObject(base, key) as? MBAssociatedWeakWrapper ?? MBAssociatedWeakWrapper()
        wrapper.object = value
        objc_setAssociatedObject(base, key, wrapper, .OBJC_ASSOCIATION_RETAIN)
    } else {
        objc_setAssociatedObject(base, key, nil, .OBJC_ASSOCIATION_RETAIN)
    }
}
