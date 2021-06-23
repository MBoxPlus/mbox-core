//
//  Array+Order.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/25.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation

extension Array {
    public mutating func bringToFirst(where condition: (Element) -> Bool) {
        if let index = self.firstIndex(where: condition) {
            let e = self.remove(at: index)
            self.insert(e, at: 0)
        }
    }

    public mutating func sendToLast(where condition: (Element) -> Bool) {
        if let index = self.lastIndex(where: condition) {
            let e = self.remove(at: index)
            self.append(e)
        }
    }
}

extension Array where Element: Equatable {
    public mutating func bringToFirst(_ o: Element) {
        if let index = self.firstIndex(of: o) {
            self.remove(at: index)
        }
        self.insert(o, at: 0)
    }

    public mutating func sendToLast(_ o: Element) {
        if let index = self.lastIndex(of: o) {
            self.remove(at: index)
        }
        self.append(o)
    }
}
