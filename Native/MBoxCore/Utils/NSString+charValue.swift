//
//  NSString+charValue.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/1/5.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

extension NSString {
    @objc
    public var charValue: CChar {
        if self.length == 0 { return 0 }
        return NSCharacterSet(charactersIn: "ty1").characterIsMember(self.character(at: 0)) ? 1:0
    }
}
