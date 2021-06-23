//
//  ThenExtension.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/9/10.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
import Then

extension Bool: Then {}

extension Optional: Then {}

extension Array where Element: Then {
    public func then(_ block: (Element) throws -> Void) rethrows -> Self {
        for e in self {
            try block(e)
        }
        return self
    }
}
