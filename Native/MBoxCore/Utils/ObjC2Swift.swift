//
//  ObjC2Swift.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/11/29.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

/// Similar to Objective-C's `@synchronized`
/// - parameter object: Token object for the lock
/// - parameter block: Block to execute inside the lock
public func synchronized<T>(_ object: NSObject, block: () throws -> T) rethrows -> T
{
    objc_sync_enter(object)
    defer {
        objc_sync_exit(object)
    }
    return try block()
}
