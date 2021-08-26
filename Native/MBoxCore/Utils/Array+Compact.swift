//
//  Array+Compact.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/9/7.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

public extension Array {
    func compact<Element>() -> [Element] {
        return self.compactMap { $0 as? Element }
    }

    func firstMap<T>(where predicate: (Element) throws -> T?) rethrows -> T? {
        for item in self {
            if let v = try predicate(item) {
                return v
            }
        }
        return nil
    }
}
