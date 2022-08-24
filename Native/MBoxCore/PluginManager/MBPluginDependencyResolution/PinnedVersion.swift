//
//  PinnedVersion.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//


import Foundation

/**
    一个依赖可以固定到的不可变版本。
        commitish代表语义版本号格式的字符串表示，由五个部分组成 主版本号、次版本号、补丁号、预发布版本标签和构建号。
        e.g
            1.0.1
            1.0.1-rc
            1.0.1-beta
            1.0.1-alpha.2
            1.0.1-alpha
            1.0.1-aaa
 
            1.0.0-alpha.1        ->          2.0 版本的语义版本号在预发布标签后面使用 . 来区分预发布的不同版本，避免 alpha2 在字符串比较上大于 alpha10 的问题。
            1.0.0-beta.5+4      ->          示这是准备发布 1.0.0 的第 5/6 个 beta 版本之后，又新增了 4 个 git 提交。
 */
struct PinnedVersion: Hashable {
    /// The commit SHA, or name of the tag, to pin to.
    let commitish: String

    init(_ commitish: String) {
        self.commitish = commitish
    }
}



/**
 
 */
extension PinnedVersion: Scannable {
    static func from(_ scanner: Scanner) -> Result<PinnedVersion, ScannableError> {
        if scanner.scanString("\"") == nil {
            return .failure(ScannableError(message: "expected pinned version", currentLine: scanner.currentLine))
        }

        guard let commitish = scanner.scanUpToString("\"") else {
            return .failure(ScannableError(message: "empty pinned version", currentLine: scanner.currentLine))
        }

        if scanner.scanString("\"") == nil {
            return .failure(ScannableError(message: "unterminated pinned version", currentLine: scanner.currentLine))
        }

        return .success(self.init(commitish))
        
//        var commitish: NSString?
//        if !scanner.scanUpTo("\"", into: &commitish) || commitish == nil {
//            return .failure(ScannableError(message: "empty pinned version", currentLine: scanner.currentLine))
//        }
//
//        if scanner.scanString("\"") == nil {
//            return .failure(ScannableError(message: "unterminated pinned version", currentLine: scanner.currentLine))
//        }
//
//        return .success(self.init(commitish! as String))
//
        
        
    }
}


extension PinnedVersion: CustomStringConvertible {
    var description: String {
        return "\"\(commitish)\""
    }
}
