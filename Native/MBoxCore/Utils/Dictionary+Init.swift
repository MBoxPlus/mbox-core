//
//  Dictionary+Init.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/9/13.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension Dictionary {
    public init<S>(_ keysAndValues: S) where S : Sequence, S.Element == (Key, Value) {
        self.init(keysAndValues) { $1 }
    }
}
