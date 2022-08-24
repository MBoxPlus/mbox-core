//
//  MBLoggerFormatter.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/30.
//  Copyright © 2018 Bytedance. All rights reserved.
//

class MBLoggerFormatter: NSObject, MBLoggerFormat {
    var logLevel: MBLogLevel = .verbose

    var lastChar: Character?
    public func indent(_ logMessage: MBLogMessage) -> String {
        var message = logMessage.message
        let level = self.logLevel
        let indent = 2 * logMessage.indents.count { level.rawValue & $0.flag.rawValue > 0 }
        if message.count > 0 && indent > 0 {
            let indent = String(repeating: " ", count: indent)
            message = message.replacingOccurrences(of: "([\r\n]+)", with: "$1\(indent)", options: .regularExpression)
            message = message.replacingOccurrences(of: "((\r*\n)+)\(indent)$", with: "$2", options: .regularExpression)
            if lastChar == nil || ["\n", "\r", "\r\n"].contains(lastChar) {
                message = indent + message
            }
        }
        lastChar = message.last
        return message
    }

    func format(logMessage: MBLogMessage) -> String? {
        var message: String = logMessage.message

        if logMessage.flag != .api {
            message = indent(logMessage)
        }
        message = message.split(separator: "\n", omittingEmptySubsequences: false)
//            .map { (line) -> Substring in
//                guard let index = line.range(of: "\r", options: .backwards)?.upperBound else { return line }
//                return line[index...]
//            }
            .joined(separator: "\n")
        return message
    }
}
