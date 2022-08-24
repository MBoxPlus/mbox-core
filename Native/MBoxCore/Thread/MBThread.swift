//
//  MBThread.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/11/16.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

public final class MBThread {
    public init(title: String?, parentThread: MBThread? = nil) {
        self.title = title
        self.parentThread = parentThread
    }

    public var statusCode: Int32 = 0
    public var error: Error?

    public weak var parentThread: MBThread?
    public lazy var subThreads = [MBThread]()
    public var isSubThread: Bool {
        return parentThread != nil
    }

    public var title: String? {
        didSet {
            self.logger.title = self.title
        }
    }

    public var runningCMDs: [MBCMD] = []
    public var isCancel: Bool = false
    public func cancel() {
        isCancel = true
        //        cmd?.cancel()
        for cmd in runningCMDs {
            cmd.cancel()
        }
    }

    public typealias CMDHook = () -> ()
    public var preRunHooks: [CMDHook] = []
    public var postRunHooks: [CMDHook] = []

    // MARK: - MultiThread
    public static var current: MBThread {
        return _current ?? MBProcess.shared.mainThread
    }

    @TaskLocal
    private static var _current: MBThread?

    private var tasks: [Task<Void, Error>] = []
    private var group = DispatchGroup()

    public func allowAsyncExec(title: String,
                               pattern: SpinnerPattern = .dots,
                               block: @escaping () throws -> Void) rethrows {
        if MBProcess.shared.allowAsync {
            self.asyncExec(title: title, pattern: pattern, block: block)
        } else {
            try self.section(title, block: block)
        }
    }

    public func asyncExec(title: String,
                          pattern: SpinnerPattern = .dots,
                          block: @escaping () throws -> Void) {
        let thread = MBThread(title: title, parentThread: self)
        self.subThreads.append(thread)
        if let filePath = self.logger.filePath {
            thread.setupFileLogger(directory: filePath.deletingPathExtension, levels: [.verbose])
        }
        if let terminal = self.terminal, terminal.isTTY {
            try? terminal.enableRawMode()
        }
        group.enter()
        let task = Task {
            let mySpinner = Spinner(pattern, title)
            if let terminal = self.terminal, terminal.isTTY {
                SpinnerManager.shared.addSpinner(mySpinner)
            }
            try MBThread.$_current.withValue(thread) {
                defer {
                    let desc = mySpinner.renderSpinner().replacingOccurrences(of: AnsiCodes.eraseRight, with: "")
                    if let parentLogPath = self.logger.filePath?.deletingLastPathComponent,
                       let logPath = UI.logger.verbFilePath {
                        self.log(info: "[\(desc)](./\(logPath.relativePath(from: parentLogPath)))", pip: .FILE)
                    }
                    group.leave()
                }
                do {
                    try block()
                    mySpinner.succeed()
                } catch {
                    mySpinner.failure()
                    if UI.statusCode == 0 {
                        UI.statusCode = 1
                    }
                    UI.log(error: error.localizedDescription)
                    throw error
                }
            }
        }
        self.tasks.append(task)
    }

    @discardableResult
    public func wait() throws -> Bool {
        group.wait()
        let status = self.subThreads.all { $0.statusCode == 0 }
        self.tasks.removeAll()
        self.subThreads.removeAll()
        if let terminal = self.terminal, terminal.isTTY {
            SpinnerManager.shared.wait()
            terminal.disabeRawMode()
        }
        let errors = self.subThreads.compactMap { $0.error }
        if !errors.isEmpty {
            throw errors.first!
        }
        return status
    }

    // MARK: logger
    public var indents: [(flag: MBLogFlag, pip: MBLoggerPipe)] = []

    public lazy var logger: MBLog = MBLog(title: self.title)

    public var terminal: Terminal?

    public func setupTerminal() {
        self.terminal = Terminal()
        self.logger.add(logger: self.terminal!)
    }

    public func setupFileLogger(directory: String? = nil, levels: [MBLogLevel]? = nil) {
        let path: String
        if let directory = directory {
            path = MBFileLogger.generateFilePath(directory: directory, title: self.title)
        } else {
            path = MBFileLogger.generateFilePath(directory: MBSetting.globalDir.appending(pathComponent: "logs"), title: self.title, date: MBProcess.shared.beginTime)
        }
        self.setupFileLogger(filePath: path, levels: levels)
    }

    public func setupFileLogger(filePath: String, levels: [MBLogLevel]? = nil) {
        for level in levels ?? [.verbose, .info] {
            self.logger.add(logger: MBFileLogger(filePath: "", level: level))
        }
        self.logger.setFilePath(filePath)
    }
}
