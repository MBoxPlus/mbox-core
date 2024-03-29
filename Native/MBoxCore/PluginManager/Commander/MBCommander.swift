//
//  MBCommander.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/6/5.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension MBLoggerAPIFormatter: ArgumentConvertible {
    public var description: String {
        return self.rawValue
    }

    public init(parser: ArgumentParser, shift: Bool = true) throws {
        if let value = parser.argument() {
            let allCases = MBLoggerAPIFormatter.allCases.map { $0.rawValue }
            if allCases.contains(value) {
                self.init(rawValue: value)!
            } else {
                throw ArgumentError.invalidValue(value: value, argument: "--api")
            }
        } else {
            throw ArgumentError.missingValue(nil)
        }
    }

}

open class MBCommander: NSObject {
    // MARK: - Command Description
    open class var name: String? {
        return nil
    }

    open class var fullName: String {
        guard let group = MBCommanderGroup.shared.group(for: self) else {
            return ""
        }
        return group.fullCmdName.joined(separator: ".")
    }

    dynamic
    open class func shouldShowInHelp() -> Bool {
        return true
    }

    dynamic
    open class var description: String? {
        return nil
    }

    open class var example: String? {
        return nil
    }

    dynamic
    open class var options: [Option] {
        return [
            Option("api", description: "Output information with API format.", values: MBLoggerAPIFormatter.allCases.map { $0.rawValue }.sorted()),
            Option("root", description: "Set Root Directory"),
            Option("home", description: "Set Configuration Home Directory"),
        ]
    }

    dynamic
    open class var flags: [Flag] {
        return [
            Flag("launcher", description: "Check Launcher environment, defaults to True"),
            Flag("verbose", flag: "v", description: "Output verbose log"),
            Flag("help", flag: "h", description: "Show help information")
        ]
    }

    dynamic
    open class var arguments: [Argument] {
        return []
    }

    dynamic
    open class var extendHelpDescription: String? {
        return nil
    }

    dynamic
    open class var autocompletionRedirect: String {
        return "##NORMAL##"
    }

    open class var forwardCommand: MBCommander.Type? {
        return nil
    }

    dynamic
    open class func autocompletion(argv: ArgumentParser) -> [String] {
        var commands = [[String]]()
        for option in options + flags {
            var line = ["--\(option.name)"]
            if let description = option.description {
                line.append(description)
            }
            commands.append(line)
            if let flag = option.flag {
                var flagLine = line
                flagLine[0] = "-\(flag)"
                commands.append(flagLine)
            }
        }
        return commands.map { $0.joined(separator: ":") }
    }

    // MARK: - Private methods to override
    open var argv: ArgumentParser!

    public override convenience init() {
        try! self.init(argv: ArgumentParser())
    }

    public required init(argv: ArgumentParser) throws {
        super.init()
        try self.setup(argv: argv)
    }

    public required init(argv: ArgumentParser, command: MBCommander) throws {
        super.init()
        try self.setup(command: command, argv: argv)
    }

    dynamic
    open func setup() throws {
        if MBProcess.shared.requireSetupLauncher {
            if type(of: self) == MBCommander.self {
                MBProcess.shared.requireSetupLauncher = false
            } else {
                MBProcess.shared.requireSetupLauncher = self.shiftFlag("launcher", default: true)
            }
        }
    }

    dynamic
    open func setup(argv: ArgumentParser) throws {
        self.argv = argv
        if self.shiftFlag("help") {
            MBProcess.shared.showHelp = true
            try help()
        }
        try setup()
    }

    dynamic
    open func setup(command: MBCommander, argv: ArgumentParser? = nil) throws {
        self.argv = argv ?? command.argv
        try setup()
    }

    open lazy var allArguments: [String: ArgumentDescriptor] = {
        var hash = [String: ArgumentDescriptor]()
        for argument in type(of: self).arguments {
            hash[argument.name] = argument
        }
        for option in type(of: self).options {
            hash[option.name] = option
        }
        for option in type(of: self).flags {
            hash[option.name] = option
        }
        return hash
    }()

    open func shiftArguments(_ name: String) -> [String] {
        guard let argument = self.allArguments[name] as? Argument else {
            assertionFailure("The parameter is not declared in the class method `arguments`: \(name)")
            return []
        }
        do {
            return try argument.parse(self.argv)
        } catch {
            return []
        }
    }

    open func shiftArgument(_ name: String) throws -> String {
        guard let argument = self.allArguments[name] as? Argument else {
            throw ArgumentError.undeclaredArgument(name)
        }
        return try argument.parse(self.argv)
    }

    open func shiftArgument(_ name: String) -> String? {
        do {
            return try shiftArgument(name) as String
        } catch {
            return nil
        }
    }

    open func shiftArgument(_ name: String, default: String? = nil) throws -> String {
        let args: String? = self.shiftArgument(name)
        if let r = args { return r }
        if let defaultValue = `default` { return defaultValue }
        throw ArgumentError.missingArgument(name)
    }

    open func hasOption(_ name: String) -> Bool {
        guard let argument = self.allArguments[name] else {
            return false
        }
        return self.argv.hasOption(argument.name, shift: false)
    }

    open func shiftOption<T: ArgumentConvertible>(_ name: String) -> T? {
        guard let argument = self.allArguments[name] else {
            return nil
        }
        if let arg = argument as? Option {
            return try? arg.parse(self.argv)
        }
        return nil
    }

    open func shiftOption<T: ArgumentConvertible>(_ name: String, default: T) -> T {
        guard let argument = self.allArguments[name] else {
            return `default`
        }
        if let arg = argument as? Option {
            return (try? arg.parse(self.argv, default: `default`)) ?? `default`
        }
        return `default`
    }

    open func shiftOptions<T: ArgumentConvertible>(_ name: String) -> [T]? {
        guard let argument = self.allArguments[name] else {
            return nil
        }
        if let arg = argument as? Option {
            return try? arg.parseMany(self.argv)
        }
        return nil
    }

    open func shiftFlag(_ name: String) -> Bool? {
        guard let argument = self.allArguments[name] else {
            return nil
        }
        if let arg = argument as? Flag {
            return try? arg.parse(self.argv)
        }
        return nil
    }

    open func shiftFlag(_ name: String, default: Bool = false) -> Bool {
        guard let argument = self.allArguments[name] else {
            return `default`
        }
        if let arg = argument as? Flag {
            return (try? arg.parse(self.argv, default: `default`)) ?? `default`
        }
        return `default`
    }

    func performAction() throws {
        try autoreleasepool {
            try UI.logger.with(pip: .ERR) {
                try setupLauncher()
            }
            try performValidateAndRun()
        }
    }

    func performValidateAndRun() throws {
        try validate()
        try? self.preRun()
        defer {
            try? self.postRun()
        }
        try performRun()
    }

    dynamic
    open func performRun() throws {
        try run()
    }

    dynamic
    open func preRun() throws {
        for hook in UI.preRunHooks {
            hook()
        }
    }

    dynamic
    open func postRun() throws {
        for hook in UI.postRunHooks {
            hook()
        }
    }

    dynamic
    open func cancel() throws {
        UI.cancel()
    }

    dynamic
    open var canCancel: Bool {
        return false
    }

    dynamic
    open func run() throws {
    }

    dynamic
    open func validate() throws {
        if !self.allowRemainderArgs && !self.argv.remainderArgs.isEmpty {
            throw ArgumentError.unknownArgument(self.argv.remainderArgs)
        }
    }

    dynamic
    open func setupLauncher(force: Bool = false) throws {
        if force || MBProcess.shared.requireSetupLauncher {
            let items = MBPluginManager.shared.requireInstallLaunchers(for: Array(MBPluginManager.shared.modules))
            if items.isEmpty { return }
            try UI.logger.with(pip: .ERR) {
                try setupLauncher(items: items)
            }
        }
    }

    open func setupLauncher(items: [MBPluginLaunchItem]) throws {
        try UI.section("Setup Environment") {
            try self.invoke(Plugin.Launch.self, argv: ArgumentParser(arguments: items.map { $0.fullName }))
        }
    }

    open var allowRemainderArgs: Bool {
        return false
    }

    open func help(_ desc: String? = nil) throws {
        throw ArgumentError.help(desc)
    }
    
    open func hookfile(_ desc: String? = nil) throws {
        throw ArgumentError.invalidCommand(desc)
    }

    open func invoke(_ cmd: MBCommander.Type, argv: ArgumentParser? = nil) throws {
        let other = try cmd.init(argv: argv ?? self.argv, command: self)
        try other.performValidateAndRun()
    }

    @discardableResult
    open func open(url: URL, withApplication appName: String? = nil) -> Bool {
        return ExternalApp(name: appName).open(url: url)
    }

    // MBox script hook
    dynamic
    open class var preScriptFileName: String {
        return "pre_\(fullName.replacingOccurrences(of: ".", with: "_"))"
    }

    dynamic
    open class var postScriptFileName: String {
        return "post_\(fullName.replacingOccurrences(of: ".", with: "_"))"
    }

    // Event Paramter
    open lazy var eventName: String = {
        return Self.fullName
    }()

    open lazy var eventParams: [String: Any] = self.setupEventParams()

    dynamic
    open func setupEventParams() -> [String: Any] {
        return [:]
    }
}
