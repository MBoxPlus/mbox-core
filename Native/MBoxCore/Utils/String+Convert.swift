//
//  String+Convert.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/11/29.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

extension String {
    public var xmlEscaped: String{
        return CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault,
                                                   self as CFString,
                                                   [:] as CFDictionary) as String
    }

    public init?(data: Data, usedEncoding: inout String.Encoding)
    {
        let encodings: [String.Encoding] = [.utf8, .utf16, .isoLatin1, .isoLatin2, .macOSRoman, .windowsCP1252]

        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                self = string
                return
            }
        }
        return nil
    }

    public func convertKebabCased() -> String {
        if (self.count == 0) { return self }
        var string = self
        var value = ""
        var lastIsKeyword = true
        while string.count > 0 {
            let first = string.removeFirst()
            if first.isUppercase {
                if !lastIsKeyword {
                    value.append("-")
                }
                value.append(String(first).lowercased())
            } else {
                value.append(first)
            }
            lastIsKeyword = first.isUppercase || first == "-"
        }
        return value
    }

    public func convertSnakeCased() -> String {
        if (self.count == 0) { return self }
        var string = self
        var value = ""
        var lastIsKeyword = true
        while string.count > 0 {
            let first = string.removeFirst()
            if first.isUppercase {
                if !lastIsKeyword {
                    value.append("_")
                }
                value.append(String(first).lowercased())
            } else {
                value.append(first)
            }
            lastIsKeyword = first.isUppercase || first == "_"
        }
        return value
    }

    public func convertCamelCased() -> String {
        if (self.count == 0) { return self }
        var string = self
        var value = ""
        var upNext = true
        while string.count > 0 {
            let first = string.removeFirst()
            if first.isLetter {
                if upNext {
                    value.append(first.uppercased())
                } else {
                    value.append(first)
                }
                upNext = false
            } else {
                if first != "-" && first != "_" {
                    value.append(first)
                }
                upNext = true
            }
        }
        return value
    }

    public var capitalizedFirstLetter: String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizedFirstLetter
    }
}
