//
//  ANSI.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/7/6.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

public enum ANSIColor: UInt8 {
    case black = 30
    case red = 31
    case green = 32
    case yellow = 33
    case blue = 34
    case magenta = 35
    case cyan = 36
    case white = 37
}

public enum ANSIFont: UInt8 {
    case bold = 1
    case italic = 3
    case underline = 4
    case strikethrough = 9

    public var resetCode: UInt8 {
        switch self {
        case .bold: return 22
        case .italic: return 23
        case .underline: return 24
        case .strikethrough: return 29
        }
    }
}

public extension String {
    func ANSI(_ ansi: ANSIFont) -> String {
        return "\u{001B}[\(ansi.rawValue)m\(self)\u{001B}[\(ansi.resetCode)m"
    }

    func ANSI(_ ansi: ANSIColor, bright: Bool = false, background: Bool = false) -> String {
        var code = ansi.rawValue
        if bright {
            code += 60
        }
        if background {
            code += 10
        }
        return "\u{001B}[\(code)m\(self)\u{001B}[0m"
    }

    var noANSI: String {
        return self.deleteRegexMatches(pattern: "\u{001B}\\[(\\d+)m")
    }
}
