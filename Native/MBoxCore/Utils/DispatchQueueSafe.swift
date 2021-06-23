//
//  DispatchQueueSafe.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/10/10.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation
extension DispatchQueue {
    public func safeAsync(execute work: @escaping @convention(block) () -> Void) {
        if OperationQueue.current?.underlyingQueue == self {
            work()
        } else {
            async(execute: work)
        }
    }
    public func safeSync<T>(execute work:() throws -> T) rethrows -> T {
        if OperationQueue.current?.underlyingQueue == self {
            return try work()
        } else {
            return try sync(execute: work)
        }
    }
}
