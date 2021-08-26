//
//  MBLoggerXcodeFormater.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/9/17.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import CocoaLumberjack

var lastLineIsNew: Bool = true
class MBLoggerXcodeFormatter: MBLoggerFormatter {
    override func hasPipe(_ pip: MBLoggerPipe) -> Bool {
        return pip.hasSTD
    }
//
//    func format(message: String, by session: MBSession, level: DDLogLevel) -> String {
//        var message = message
//        if let name = UI.fullTitle,
//            message.trimmingCharacters(in: .whitespaces).count > 0 {
//            let prefix = "[\(name)] "
//            if lastLineIsNew {
//                message = prefix + message
//            }
//            let hasNewline = message.hasSuffix("\n") || message.hasSuffix("\r")
//            lastLineIsNew = hasNewline
//            if hasNewline {
//                message = String(message.dropLast(1))
//            }
//            message = message.replacingOccurrences(of: "\n", with: "\n\(prefix)")
//            if hasNewline {
//                message.append("\n")
//            }
//        }
//        return message
//    }
}
