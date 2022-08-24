//
//  String+Regex.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/9/29.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension String {
    public func match(regex: String) throws -> [[String]]? {
        let regex = try NSRegularExpression(pattern: regex, options: [])
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        if results.count == 0 {
            return nil
        }
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }

    public func isMatch(regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }

    public func replace(regex: String, block: (_ match: NSTextCheckingResult) -> String?) -> String {
        let regex = try! NSRegularExpression(pattern: regex, options: [])
        var value = ""
        var lastPointer = 0
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, self.lengthOfBytes(using: .utf8))) { result, _, _ in
            guard let result = result else { return }
            if result.range.lowerBound > lastPointer {
                value.append(nsString.substring(with: NSMakeRange(lastPointer, result.range.lowerBound - lastPointer)))
            }
            if let v = block(result) {
                value.append(v)
            }
            lastPointer = result.range.upperBound
        }
        if nsString.length > lastPointer {
            value.append(nsString.substring(with: NSMakeRange(lastPointer, nsString.length - lastPointer)))
        }
        return value
    }
}

infix operator =~
public func =~(string:String, regex:String) -> Bool {
    return string.isMatch(regex: regex)
}

infix operator !~
public func !~(string:String, regex:String) -> Bool {
    return !string.isMatch(regex: regex)
}
