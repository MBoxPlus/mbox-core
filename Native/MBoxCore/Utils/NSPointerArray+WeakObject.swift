//
//  NSPointerArray+WeakObject.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/10/12.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

extension NSPointerArray {
    func addWeakObject(_ object: AnyObject?) {
        guard let strongObject = object else { return }

        let pointer = Unmanaged.passUnretained(strongObject).toOpaque()
        addPointer(pointer)
    }

    func insertWeakObject(_ object: AnyObject?, at index: Int) {
        guard index < count, let strongObject = object else { return }

        let pointer = Unmanaged.passUnretained(strongObject).toOpaque()
        insertPointer(pointer, at: index)
    }

    func replaceWeakObject(at index: Int, withObject object: AnyObject?) {
        guard index < count, let strongObject = object else { return }

        let pointer = Unmanaged.passUnretained(strongObject).toOpaque()
        replacePointer(at: index, withPointer: pointer)
    }

    func weakObject(at index: Int) -> AnyObject? {
        guard index < count, let pointer = self.pointer(at: index) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue()
    }

    func removeWeakObject(at index: Int) {
        guard index < count else { return }

        removePointer(at: index)
    }

    func removeWeekObject(_ object: AnyObject?) {
        var i = 0
        while i < count {
            if weakObject(at: i) === object {
                removeWeakObject(at: i)
                return
            }
            i += 1
        }
    }
}
