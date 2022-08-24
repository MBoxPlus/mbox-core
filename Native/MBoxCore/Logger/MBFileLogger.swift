//
//  MBLogFileManager.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/29.
//  Copyright © 2018 Bytedance. All rights reserved.
//

class MBFileLogger: MBLogger {
    var async: Bool = true
    var queue: DispatchQueue
    var level: MBLogLevel = .info
    var logFormatter: MBLoggerFormat? = MBLoggerFormatter()
    var pip: MBLoggerPipe = .INFOFILE

    deinit {
        self.close()
    }

    init(filePath: String, level: MBLogLevel) {
        self.filePath = filePath
        self.level = level
        if level == .verbose {
            self.pip = .VERBFILE
        }
        self.queue = DispatchQueue(label: "mbox.filelogger.\(level)")
    }

    func isSupport(pip: MBLoggerPipe) -> Bool {
        return pip.contains(self.pip)
    }

    public private(set) var filePath: String {
        didSet {
            self.close()
        }
    }

    public func move(filePath: String) {
        if self.filePath == filePath { return }
        self.queue.async {
            self.close()
            if self.filePath.isExists, !filePath.isExists {
                try? FileManager.default.createDirectory(atPath: filePath.deletingLastPathComponent, withIntermediateDirectories: true)
                try? FileManager.default.moveItem(atPath: self.filePath, toPath: filePath)
            }
            self.filePath = filePath
        }
    }

    // MARK: - File
    private func loadFileHandle() throws -> FileHandle {
        if !self.filePath.isExists {
            try? FileManager.default.createDirectory(atPath: self.filePath.deletingLastPathComponent, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: self.filePath, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: self.filePath) else {
            throw RuntimeError("Create filehandle failed.\(self.filePath)")
        }
        handle.seekToEndOfFile()
        return handle
        
    }

    private var _fileHandle: FileHandle?
    private var fileHandle: FileHandle? {
        set {
            _fileHandle = newValue
        }
        get {
            if let v = _fileHandle {
                return v
            }
            let v = try? loadFileHandle()
            _fileHandle = v
            return v
        }
    }

    func close() {
        try? _fileHandle?.synchronize()
        try? _fileHandle?.close()
        _fileHandle = nil
    }

    func logMessage(_ logMessage: MBLogMessage) {
        self.fileHandle?.seekToEndOfFile()
        self.fileHandle?.write(logMessage.message)
    }

    // MARK: - Static Methods
    public static func generateFilePath(directory: String? = nil, title: String? = nil, date: Date? = nil, verbose: Bool = false) -> String {
        var path = directory ?? FileManager.supportDirectory.appending(pathComponent:"logs")
        if let date = date {
            path = path.appending(pathComponent: self.formattedDateString(date: date))
                .appending(pathComponent: MBCMD.isCMDEnvironment ? "CLI" : "GUI")
                .appending(pathComponent: self.formattedTimeString(date: date))
            path.append(" ")
        } else {
            path.append("/")
        }
        if let title = title {
            let title = title.slicing(from: 0, length: 200) ?? title
            path.append(title.replacingOccurrences(of: "/", with: "_"))
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
