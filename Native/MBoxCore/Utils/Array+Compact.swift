//
//  Array+Compact.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/9/7.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation

public extension Array {
    func compact<Element>() -> [Element] {
        return self.compactMap { $0 as? Element }
    }
}
