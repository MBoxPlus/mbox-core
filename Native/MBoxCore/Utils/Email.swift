//
//  Email.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/3/25.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

public struct Email {
    public private(set) var string: String
    public private(set) var userName: String
    public private(set) var domain: String

    public init?(_ string: String) {
        guard let index = string.lastIndex(of: "@") else {
            return nil
        }
        self.string = string
        self.userName = String(string[..<index])
        self.domain = String(string[(string.index(index, offsetBy: 1))...])
    }
}
