//
//  MBProcess.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/29.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

public final class MBProcess {
    public static let shared = MBProcess()

    public init() {
        self.beginTime = Date()
    }

    // MARK: - Environment
    public var args: ArgumentParser!
    public var devRoot: String?
    public var showHelp: Bool = false
    public var apiFormatter: MBLoggerAPIFormatter = .none
    public var fromGUI: Bool = ProcessInfo.processInfo.removeEnvironment(name: "MBOX_GUI") != nil
    public lazy var rootPath: String = FileManager.pwd
    dynamic
    public func setupEnvironment() -> [String: String] {
        return ProcessInfo.processInfo.environment
    }
    public lazy var environment: [String : String] = self.setupEnvironment()

    // MARK: Verbose
    public var verbose: Bool = false
    @discardableResult
    public func with<T>(verbose: Bool, block: () throws -> T) rethrows -> T {
        if self.verbose == verbose {
            return try block()
        }
        let v = self.verbose
        defer { self.verbose = v }
        self.verbose = verbose
        return try block()
    }

    // MARK: - Timer
    public var duration: TimeInterval {
        return (self.endTime ?? Date()).timeIntervalSince(self.beginTime)
    }

    public private(set) var beginTime: Date
    public private(set) var endTime: Date?
    public func endTimer() {
        self.endTime = Date()
    }

    // MARK: - Thread
    public var allowAsync = false
    @discardableResult
    public func with<T>(allowAsync: Bool, block: () throws -> T) rethrows -> T {
        if self.allowAsync == allowAsync {
            return try block()
        }
        let v = self.allowAsync
        defer { self.allowAsync = v }
        self.allowAsync = allowAsync
        return try block()
    }

    public lazy var mainThread: MBThread = {
        let thread = MBThread(title: "Main Thread")
        Thread.current.threadDictionary.setValue(thread, forKey: "MBThread")
        if MBCMD.isCMDEnvironment {
            thread.setupTerminal()
        }
        return thread
    }()

    // MARK: - Logger
    public private(set) lazy var warnings = [MBThread.LogInfo]()
    public private(set) lazy var errors = [MBThread.LogInfo]()
    public private(set) lazy var infos = [MBThread.LogInfo]()
    private lazy var queue = DispatchQueue(label: "MBProcess")
    public func addSummary(_ flag: MBLogFlag, info: MBThread.LogInfo) {
        self.queue.safeSync {
            switch flag {
            case .error:
                self.errors << info
            case .warning:
                self.warnings << info
            case .info:
                self.infos << info
            default: break
            }
        }
    }

    // MARK: - Plugins
    dynamic
    public var plugins: [String: [MBSetting.PluginDescriptor]] {
        var value = ["MBoxCore": [MBSetting.PluginDescriptor(requiredBy: "Application")]]
        MBSetting.global.plugins?.forEach { (name, desc) in
            var v = value[name] ?? []
            v.append(desc)
            value[name] = v
        }
        return value
    }

    dynamic
    public var recommendedPlugins: [String: [MBSetting.PluginDescriptor]] {
        var result: [String: [MBSetting.PluginDescriptor]] = [:]
        self.cachedPlugins.forEach() { plugin, value in
            let package = MBPluginManager.shared.allPackages.first { (pluginPackage) -> Bool in
                return plugin.lowercased() == pluginPackage.name.lowercased()
            }
            guard package == nil else {
                return
            }
            result[plugin] = value
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

    // MARK: - Launcher
    public lazy var requireSetupLauncher = true

}
