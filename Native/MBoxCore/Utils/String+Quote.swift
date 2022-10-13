//
//  String+Quote.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/12/1.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

extension String {
    public var quoted: String {
        if self.contains(" ") && (self !~ "^['\"].*['\"]$") {
            return "'\(self)'"
        }
        if self.contains("&") {
            return "'\(self)'"
        }
        return self
    }
}
