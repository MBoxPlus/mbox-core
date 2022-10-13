//
//  DispatchQueueSafe.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/10/10.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation
extension DispatchQueue {
    private static let isCurrentQueueKey = DispatchSpecificKey<String>()

    public func safeSync(execute workItem: DispatchWorkItem) {
        self.setSpecific(key: DispatchQueue.isCurrentQueueKey, value: self.label)
        defer {
            self.setSpecific(key: DispatchQueue.isCurrentQueueKey, value: nil)
        }

        guard DispatchQueue.getSpecific(key: DispatchQueue.isCurrentQueueKey) == self.label else {
            return self.sync(execute: workItem)
        }

        return workItem.perform()
    }

    public func safeSync<T>(execute work:() throws -> T) rethrows -> T {
        self.setSpecific(key: DispatchQueue.isCurrentQueueKey, value: self.label)
        defer {
            self.setSpecific(key: DispatchQueue.isCurrentQueueKey, value: nil)
        }

        guard DispatchQueue.getSpecific(key: DispatchQueue.isCurrentQueueKey) == self.label else {
            return try self.sync(execute: work)
        }

        return try work()
    }
}
