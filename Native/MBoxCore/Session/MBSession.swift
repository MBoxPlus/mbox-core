//
//  MBSession.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/29.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

open class MBSession: NSObject {

    public init(title: String?, isMain: Bool = false) {
        self.title = title
        self.isMainSession = isMain
        super.init()
        self.logger.setLogFile(with: MBSetting.globalDir.appending(pathComponent: "logs"))
    }

    public lazy var rootPath: String = FileManager.pwd

    // MARK: - Plugins
    dynamic
    open var plugins: [String: [MBSetting.PluginDescriptor]] {
        var value = [String: [MBSetting.PluginDescriptor]]()
        MBSetting.global.plugins?.forEach { (name, desc) in
            var v = value[name] ?? []
            v.append(desc)
            value[name] = v
        }
        return value
    }

    dynamic
    open var recommendedPlugins: [String: [MBSetting.PluginDescriptor]] {
        var result: [String: [MBSetting.PluginDescriptor]] = [:]
        for (plugin, desc) in self.cachedPlugins {
            guard MBPluginManager.shared.package(for: plugin) == nil else {
                continue
            }
            result[plugin] = desc
        }
        return result
    }

    public lazy var cachedPlugins: [String: [MBSetting.PluginDescriptor]] = {
        _ = self.plugins
        return self.plugins
    }()

    public func reloadPlugins() {
        self.cachedPlugins = self.plugins
        MBPluginManager.shared.loadAll()
    }

    open lazy var requireSetupLauncher = true

    // MARK: - Status
    public var statusCode: Int32 = 0

    public weak var parentSession: MBSession?
    public weak var mainSession: MBSession?
    public private(set) var isMainSession: Bool
    public var subSessions = [MBSession]()
    public var isSubSession: Bool {
        return parentSession != nil
    }

    public var mainTitle: String?
    public var title: String? {
        didSet {
            if mainTitle == nil || !isSubSession {
                mainTitle = title
            }
        }
    }
    public var fullTitle: String? {
        if let mainTitle = self.mainTitle {
            if let title = self.title, title != mainTitle {
                return "\(mainTitle)|\(title)"
            }
            return mainTitle
        }
        return title
    }

    public var indents: [MBLogFlag] = []

    public static var current: MBSession?

    open var runningCMDs: [MBCMD] = []
    public var isCancel: Bool = false
    public func cancel() {
        isCancel = true
//        cmd?.cancel()
        for cmd in runningCMDs {
            cmd.cancel()
        }
    }

    public var dispatchGroup: DispatchGroup?

    public var duration: TimeInterval = 0

    public var fromGUI: Bool = ProcessInfo.processInfo.removeEnvironment(name: "MBOX_GUI") != nil

    // MARK: logger
    open var verbose: Bool = false {
        didSet {
            self.logger.verbose = self.verbose
        }
    }

    @discardableResult
    open func with<T>(verbose: Bool, block: () throws -> T) rethrows -> T {
        if self.verbose == verbose {
            return try block()
        }
        let v = self.verbose
        defer { self.verbose = v }
        self.verbose = verbose
        return try block()
    }

    open var args: ArgumentParser!
    open var devRoot: String?
    open var showHelp: Bool = false
    open var apiFormatter: MBLoggerAPIFormatter = .none {
        didSet {
            self.logger.api = self.apiFormatter
        }
    }

    open lazy var logger: MBLog = MBLog(title: self.title)

    public struct LogInfo {
        public var flag: MBLogFlag
        public var message: String
        public var items: [String]?
        public var file: StaticString
        public var function: StaticString
        public var line: UInt

        public var description: String {
            var strings = [String]()
            switch flag {
            case .warning:
                strings << "[!] \(message)".ANSI(.yellow)
            case .error:
                strings << "[X] \(message)".ANSI(.red, bright: true)
            default:
                strings << message
            }
            if let items = self.items {
                for item in items {
                    strings.append("  " + item)
                }
            }
            return strings.joined(separator: "\n")
        }
    }
    open lazy var warnings: [LogInfo] = [LogInfo]()
    open lazy var errors: [LogInfo] = [LogInfo]()
    open lazy var infos: [LogInfo] = [LogInfo]()
}
