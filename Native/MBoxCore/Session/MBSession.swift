//
//  MBSession.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/29.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation
import CocoaLumberjack

open class MBSession: NSObject {

    public convenience init(title: String?, isMain: Bool = false) {
        self.init(isMain: isMain)
        self.title = title
    }

    public init(isMain: Bool = false) {
        self.isMainSession = isMain
        super.init()
    }

    public lazy var rootPath: String = FileManager.pwd

    // MARK: - Plugins
    dynamic
    open var plugins: [String: [MBSetting.PluginDescriptor]] {
        var value = ["MBoxCore": [MBSetting.PluginDescriptor(requiredBy: "Application")]]
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
        self.cachedPlugins.forEach() { plugin, value in
            let package = MBPluginManager.shared.allPackages.first { (key, pluginPackage) -> Bool in
                return plugin.lowercased() == pluginPackage.name.lowercased()
            }
            guard package == nil else {
                return
            }
            result[plugin] = value
        }
        return result
    }

    dynamic
    public func requiredPlugins(_ packages: [MBPluginPackage]) -> [MBPluginPackage] {
        return packages.filter { $0.required }
    }

    public lazy var cachedPlugins: [String: [MBSetting.PluginDescriptor]] = {
        // 为了防止 Swift dynamic replacement 第一次未生效，故意执行两遍
        _ = self.plugins
        return self.plugins
    }()

    public func reloadPlugins() {
        self.cachedPlugins = self.plugins
        MBPluginManager.shared.loadAll()
    }

    public var activedPlugins: [MBPluginPackage] {
        return MBPluginManager.shared.dependencies(for: cachedPlugins.map { $0.key })
    }

    public func activedPlugin(for name: String) -> MBPluginPackage? {
        return activedPlugins.first { $0.isPlugin(name) }
    }

    public func isEnable(forPlugin name: String) -> Bool {
        return activedPlugins.contains { $0.isPlugin(name) }
    }

    public func isEnable(forPlugin klass: AnyClass) -> Bool {
        let name = getModuleName(forClass: klass)
        return isEnable(forPlugin: name)
    }

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

    public var indents: [DDLogFlag] = []

    public static var main = MBSession()

    public static var current: MBSession? = main

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

    public var fromGUI: Bool = ProcessInfo.processInfo.environment["MBOX_GUI"] != nil

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

    open var defaultPipe = MBLoggerPipe.OUT

    @discardableResult
    public func with<T>(pip: MBLoggerPipe, block: () throws -> T) rethrows -> T {
        if self.defaultPipe == pip {
            return try block()
        }
        let v = self.defaultPipe
        defer { self.defaultPipe = v }
        self.defaultPipe = pip
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

    open lazy var logger: MBLogger = MBLogger(title: self.title)
    open var verbLogFilePath: String? {
        set {
            logger.verbFilePath = newValue
        }
        get {
            return logger.verbLogFileInfo?.filePath
        }
    }
    open var infoLogFilePath: String? {
        set {
            logger.infoFilePath = newValue
        }
        get {
            return logger.infoLogFileInfo?.filePath
        }
    }
    public var logDirectory: String? {
        set {
            logger.logDirectory = newValue
        }
        get {
            return logger.logDirectory
        }
    }

    public struct LogInfo {
        public var flag: DDLogFlag
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
