//
//  MBLogger.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/29.
//  Copyright © 2018 Bytedance. All rights reserved.
//

struct MBLogMessage {
    var message: String
    var flag: MBLogFlag
    var context: Int
    var pip: MBLoggerPipe
    var fileName: StaticString
    var function: StaticString
    var line: UInt
    var tag: Any?
    var indents: [(flag: MBLogFlag, pip: MBLoggerPipe)]
}

protocol MBLoggerFormat {
    func format(logMessage: MBLogMessage) -> String?
}

protocol MBLogger {
    var async: Bool { get }
    var queue: DispatchQueue { get }
    var level: MBLogLevel { get }
    var logFormatter: MBLoggerFormat? { get }
    func logMessage(_ logMessage: MBLogMessage)
    func isSupport(pip: MBLoggerPipe) -> Bool
    func close()
}

public enum MBLogFlag: UInt {
    case error = 1
    case warning = 2
    case api = 4
    case info = 8
    case debug = 16
    case verbose = 32
}

public struct MBLogLevel: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    static let off = MBLogLevel([])
    static let error = MBLogLevel(rawValue: MBLogFlag.error.rawValue)
    static let warning = MBLogLevel(rawValue: MBLogLevel.error.rawValue + MBLogFlag.warning.rawValue)
    static let info = MBLogLevel(rawValue: MBLogLevel.warning.rawValue + MBLogFlag.info.rawValue + MBLogFlag.api.rawValue)
    static let debug = MBLogLevel(rawValue: MBLogLevel.info.rawValue + MBLogFlag.debug.rawValue)
    static let verbose = MBLogLevel(rawValue: MBLogLevel.debug.rawValue + MBLogFlag.verbose.rawValue)
}

public struct MBLoggerPipe: OptionSet {
    public let rawValue: Int

    public static let STDOUT = MBLoggerPipe(rawValue: 1 << 0)
    public static let STDERR = MBLoggerPipe(rawValue: 1 << 1)
    public static let INFOFILE = MBLoggerPipe(rawValue: 1 << 3)
    public static let VERBFILE = MBLoggerPipe(rawValue: 1 << 4)

    public static let STD: MBLoggerPipe = [.STDOUT, .STDERR]
    public static let FILE: MBLoggerPipe = [.INFOFILE, .VERBFILE]

    public static let OUT: MBLoggerPipe = [.STDOUT, .FILE]
    public static let ERR: MBLoggerPipe = [.STDERR, .FILE]
    public static let ALL: MBLoggerPipe = [.STD, .FILE]

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

open class MBLog {

    public var title: String?

    init(title: String? = nil) {
        self.title = title
    }

    // MARK: - Pipe
    public var avaliablePipe: MBLoggerPipe = .ALL
    public func with(pip: MBLoggerPipe, block: (() throws -> Void)) rethrows {
        let lastPip = self.avaliablePipe
        self.avaliablePipe = pip
        defer {
            self.avaliablePipe = lastPip
        }
        try block()
    }

    // MARK: - Loggers
    private var loggers: [MBLogger] = []

    func add(logger: MBLogger) {
        self.loggers.append(logger)
    }

    // MARK: Console Logger
    var consoleLogger: Terminal? {
        return self.loggers.compactMap { $0 as? Terminal }.first
    }

    // MARK: File Logger
    var fileLoggers: [MBFileLogger] {
        return self.loggers.compactMap { $0 as? MBFileLogger }
    }

    public var customFilePath: Bool = false
    public private(set) var filePath: String?
    public var verbFilePath: String? {
        self.fileLoggers.first { $0.level == .verbose }?.filePath
    }

    public func setFilePath(_ filePath: String) {
        if customFilePath { return }
        self.filePath = filePath
        for logger in self.fileLoggers {
            var path = filePath
            if logger.level == .verbose {
                path = path.deletingPathExtension.appending(pathExtension: "verbose").appending(pathExtension: path.pathExtension)
            }
            logger.move(filePath: path)
        }
    }

    public func setFilePath(with directory: String) {
        self.setFilePath(MBFileLogger.generateFilePath(directory: directory, title: self.title, date: MBProcess.shared.beginTime))
    }

    // MARK: - API
    public func log(message: String,
                    flag: MBLogFlag,
                    pip: MBLoggerPipe? = nil,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line,
                    newLine: Bool = true) {
        var message = message
        if newLine {
            message.append("\n")
        }
        var pip = pip ?? self.avaliablePipe
        if flag == .error || flag == .warning {
            pip = .ERR
        }
        if pip.hasSTD {
            if flag == .api {
                pip = pip.withSTD(.OUT)
            } else if MBProcess.shared.apiFormatter != .none {
                pip = pip.withSTD(.ERR)
            }
        }
        let logMessage = MBLogMessage(message: message, flag: flag, context: 0, pip: pip, fileName: file, function: function, line: line, tag: 0, indents: UI.indents)
        self.log(message: logMessage, asynchronous: false)
    }

    private func log(message: MBLogMessage,
                     asynchronous: Bool) {
        let pip = message.pip.intersection(self.avaliablePipe)
        if pip.isEmpty {
            return
        }
        for logger in self.loggers {
            if logger.level.rawValue & message.flag.rawValue == 0 {
                continue
            }
            if !logger.isSupport(pip: pip) {
                continue
            }
            var logMessage = message
            let block = {
                if let logFormatter = logger.logFormatter {
                    guard let message = logFormatter.format(logMessage: logMessage) else {
                        return
                    }
                    logMessage.message = message
                }
                logger.logMessage(logMessage)
            }
            if logger.async {
                logger.queue.async(execute: block)
            } else {
                logger.queue.sync(execute: block)
            }
        }
    }

    public func wait(close: Bool = false) {
        let group = DispatchGroup()
        for logger in self.loggers {
            group.enter()
            logger.queue.async {
                if close {
                    logger.close()
                }
                group.leave()
            }
        }
        group.wait()
    }
}
