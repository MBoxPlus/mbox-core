//
//  MBLogFileManager.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/29.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import CocoaLumberjack

class MBLogFileManager: DDLogFileManagerDefault {

    convenience init(logPath: String) {
        self.init(logsDirectory: logPath.deletingLastPathComponent)
        self.fileName = logPath.lastPathComponent
        self.maximumNumberOfLogFiles = 0 // disable limit
    }

    private var fileName: String = ""
    override open var newLogFileName: String {
        return fileName
    }

    override open func isLogFile(withName fileName: String) -> Bool {
        return fileName.hasSuffix(".log")
    }

    // MARK: - Static Methods
    public static func generateFilePath(directory: String? = nil, title: String? = nil, date: Date = Date(), verbose: Bool = false) -> String {
        var path = directory ?? FileManager.supportDirectory.appending(pathComponent:"logs")
        path = path.appending(pathComponent: self.formattedDateString(date: date))
            .appending(pathComponent: MBCMD.isCMDEnvironment ? "CLI" : "GUI")
            .appending(pathComponent: self.formattedTimeString(date: date))
        if let title = title {
            let title = title.slicing(from: 0, length: 30) ?? title
            path.append(" \(title.replacingOccurrences(of: "/", with: "_"))")
        }
        if verbose {
            path = path.appending(pathExtension: "verbose")
        }
        return path.appending(pathExtension:"log")
    }

    static func formattedDateString(date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    static var _cacheDateFormatter: DateFormatter?
    static var dateFormatter: DateFormatter {
        if let formatter = _cacheDateFormatter {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.init(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy'-'MM'-'dd'"
        _cacheDateFormatter = formatter
        return formatter
    }


    static func formattedTimeString(date: Date) -> String {
        return timeFormatter.string(from: date)
    }

    static var _cacheTimeFormatter: DateFormatter?
    static var timeFormatter: DateFormatter {
        if let formatter = _cacheTimeFormatter {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.init(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH'-'mm'-'ss'-'SSS'"
        _cacheTimeFormatter = formatter
        return formatter
    }
}
