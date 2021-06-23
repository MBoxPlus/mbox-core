//
//  MBLogger.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/29.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import CocoaLumberjack

extension DDLogFlag {
    public static let api = DDLogFlag(rawValue: 1 << 5)
}

public struct MBLoggerPipe: OptionSet {
    public let rawValue: Int

    public static let STDOUT = MBLoggerPipe(rawValue: 1 << 0)
    public static let STDERR = MBLoggerPipe(rawValue: 1 << 1)
    public static let FILE = MBLoggerPipe(rawValue: 1 << 2)

    public static let STD: MBLoggerPipe = [.STDOUT, .STDERR]
    public static let OUT: MBLoggerPipe = [.STDOUT, .FILE]
    public static let ERR: MBLoggerPipe = [.STDERR, .FILE]
    public static let ALL: MBLoggerPipe = [.STDOUT, .STDERR, .FILE]

    public var hasSTD: Bool {
        return self.contains(.STDERR) || self.contains(.STDOUT)
    }

    public var hasFile: Bool {
        return self.contains(.FILE)
    }

    public func withSTD(_ std: MBLoggerPipe) -> MBLoggerPipe {
        return self.intersection(.FILE).union(std)
    }

    public func withoutSTD() -> MBLoggerPipe {
        return self.intersection(.FILE)
    }

    public func withoutFILE() -> MBLoggerPipe {
        return self.intersection(.STD)
    }

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public enum MBLoggerAPIFormatter: String, CaseIterable {
    case none = "none"
    case json = "json"
    case yaml = "yaml"
    case plain = "plain"
}

open class MBLogger: DDLog {

    public var title: String?

    init(title: String? = nil) {
        self.title = title
        super.init()

        if MBCMD.isCMDEnvironment {
            updateConsoleLoggerLevel()
        }
    }

    public var avaliablePipe: MBLoggerPipe = .ALL

    public var verbose: Bool = false {
        didSet {
            if oldValue == verbose {
                return
            }
            updateConsoleLoggerLevel()
        }
    }

    public var api: MBLoggerAPIFormatter = .none {
        didSet {
            if oldValue == api {
                return
            }
            updateConsoleLoggerLevel()
        }
    }

    // MARK: - Console
    public lazy var consoleLogger: MBTTYLogger = {
        let logger = MBTTYLogger.sharedInstance()!
        logger.colorsEnabled = true
        logger.logFormatter = MBLoggerXcodeFormatter()
        logger.automaticallyAppendNewlineForCustomFormatters = false
        logger.useStandardStyleForCustomFormatters = false
        return logger
    }()

    private func updateConsoleLoggerLevel() {
        self.remove(self.consoleLogger)
        var level: DDLogLevel = verbose ? .all : .info
        level = DDLogLevel(rawValue: level.rawValue | DDLogFlag.api.rawValue)!
        if let formatter = self.consoleLogger.logFormatter as? MBLoggerFormatter {
            formatter.logLevel = level
        }
        self.add(self.consoleLogger, with: level)
    }

    // MARK: - File
    public var infoFilePath: String? {
        didSet {
            if let fileLogger = self.infoFileLogger {
                self.remove(fileLogger)
                self.infoFileLogger = nil
            }
            if let path = infoFilePath {
                let logger = self.setupFileLogger(path: path)
                self.add(logger, with: DDLogLevel(rawValue: DDLogLevel.info.rawValue + DDLogFlag.api.rawValue)!)
                self.infoFileLogger = logger
            }
        }
    }
    public var verbFilePath: String? {
        didSet {
            if let fileLogger = self.verbFileLogger {
                self.remove(fileLogger)
                self.verbFileLogger = nil
            }
            if let path = verbFilePath {
                let logger = self.setupFileLogger(path: path)
                self.add(logger, with: DDLogLevel(rawValue: DDLogLevel.verbose.rawValue + DDLogFlag.api.rawValue)!)
                self.verbFileLogger = logger
            }
        }
    }
    public var infoFileLogger: DDFileLogger?
    public var verbFileLogger: DDFileLogger?
    public func setupFileLogger(path: String) -> DDFileLogger {
        let fm = MBLogFileManager(logPath: path)
        let logger = DDFileLogger(logFileManager: fm)
        logger.automaticallyAppendNewlineForCustomFormatters = false
        logger.doNotReuseLogFiles = true
        logger.logFormatter = MBLoggerFormatter()
        return logger
    }

    public var logDirectory: String? {
        set {
            if (!self.avaliablePipe.hasFile) { return }
            if self.infoFilePath != nil { return }
            guard let dir = newValue else { return }
            let date = Date()
            self.infoFilePath = MBLogFileManager.generateFilePath(directory: dir, title: self.title, date: date, verbose: false)
            self.verbFilePath = MBLogFileManager.generateFilePath(directory: dir, title: self.title, date: date, verbose: true)
        }
        get {
            return self.infoFileLogger?.logFileManager.logsDirectory
        }
    }

    public var verbLogFileInfo: DDLogFileInfo? {
        return self.verbFileLogger?.currentLogFileInfo
    }

    public var infoLogFileInfo: DDLogFileInfo? {
        return self.infoFileLogger?.currentLogFileInfo
    }

    // MARK: - API
    public func log(message: String,
                    session: MBSession,
                    level: DDLogLevel,
                    flag: DDLogFlag,
                    pip: MBLoggerPipe? = nil,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line,
                    newLine: Bool = true) {
        var string = message
        if newLine {
            string.append("\n")
        }
        var pip = pip ?? (flag.contains(.error) || flag.contains(.warning) ? MBLoggerPipe.ERR : MBLoggerPipe.OUT)
        pip = pip.intersection(self.avaliablePipe)
        var std: MBLoggerPipe = pip
        if pip.hasSTD {
            if flag == .api {
                std = std.withSTD(.OUT)
            } else if UI.apiFormatter != .none {
                std = std.withSTD(.ERR)
            }
        }
        _DDLogMessage(string,
                      level: level,
                      flag: flag,
                      context: std.rawValue,
                      file: file,
                      function: function,
                      line: line,
                      tag: session,
                      asynchronous: false,
                      ddlog: self)
    }

}
