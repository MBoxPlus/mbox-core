//
//  MBCMD.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/9/17.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation
import ObjCCommandLine

extension Dictionary where Key == String, Value == String {
    public mutating func unshift(env: String, for key: String) {
        if let v = self[key] {
            self[key] = "\(env):\(v)"
        } else {
            self[key] = env
        }
    }
    public mutating func mergeEnvironment(env: [String: String]) {
        var path: String? = nil
        if let path1 = self["PATH"], let path2 = env["PATH"] {
            path = "\(path2):\(path1)"
        }
        self.merge(env) { (_, r) -> String in
            return r
        }
        if let path = path {
            self["PATH"] = path
        }
    }
}

extension ObjCShell: MBInputHandlerDelegate {
    public func userInput(_ data: Data) {
        self.appendInput(data);
    }
}

open class MBCMD: NSObject {
    open var useTTY: Bool
    open class var isCMDEnvironment: Bool {
        set {
            ObjCShell.isCMDEnvironment = newValue
        }
        get {
            return ObjCShell.isCMDEnvironment
        }
    }

    private lazy var shell: ObjCShell = ObjCShell(tty: useTTY)
    open var outputString: String {
        return shell.outputString
    }
    open var errorString: String {
        return shell.errorString
    }

    open var workingDirectory: String?

    dynamic
    open func setupEnvironment(_ base: [String: String]? = nil) -> [String: String] {
        var env = base ?? [:]
        env["MBox"] = MBoxCore.bundle.shortVersion
        env["MBOX_ARGS"] = UI.args.rawDescription
        env["NSUnbufferedIO"] = "YES"
        env["MBOX_CLI_PATH"] = ProcessInfo.processInfo.arguments.first!
        return env
    }
    public lazy var env: [String: String] = setupEnvironment()

    public convenience init(workingDirectory: String, useTTY: Bool? = nil) {
        self.init(useTTY: useTTY)
        self.workingDirectory = workingDirectory
    }

    dynamic
    public required init(useTTY: Bool? = nil) {
        self.useTTY = useTTY ?? !UI.fromGUI
        super.init()
        self.setup()
    }

    dynamic
    open func setup() {
    }

    open func setupExecute() throws {
    }

    public var showOutput: Bool = false

    func scriptPath(name: String, ofType: String) -> String {
        return ObjCShell.script(forName: name, ofType: ofType)
    }

    open var bin: String = ""

    open var binExists: Bool {
        return Self.executableExists(self.bin, env: self.env)
    }

    open func cmdString(_ string: String, sudo: Bool = false, prompt: String? = nil) -> String {
        let string = bin.isEmpty ? string : "\(bin) \(string)"
        if sudo {
            return ObjCShell.command(withAdministrator: string, prompt: prompt ?? "Password:")!
        }
        return string
    }

    @discardableResult
    open func exec(_ string: String, workingDirectory: String? = nil, env: [String: String]? = nil) -> Int32 {
        return self.exec(string, workingDirectory: workingDirectory, env: env, sudo: false, prompt: nil)
    }

    dynamic
    open func exec(_ string: String, workingDirectory: String? = nil, env: [String: String]? = nil, statusCodes: [Int32] = [0]) -> Bool {
        let code: Int32 = self.exec(string, workingDirectory: workingDirectory, env: env)
        if statusCodes.contains(code) {
            return true
        }
        return false
    }

    open func sudoExec(_ string: String, prompt: String, workingDirectory: String? = nil, env: [String: String]? = nil) throws {
        if self.exec(string, workingDirectory: workingDirectory, env: env, sudo: true, prompt: prompt) != 0 {
            throw RuntimeError()
        }
    }

    dynamic
    open func exec(_ string: String, workingDirectory: String?, env: [String: String]?, sudo: Bool, prompt: String?) -> Int32 {
        try? self.setupExecute()
        if let code = exitSignal { return code }
        let workingDirectory = workingDirectory ?? self.workingDirectory
        let string = self.cmdString(string, sudo: sudo)
        let title = workingDirectory == nil || workingDirectory == FileManager.pwd ? "" : "$ cd \(workingDirectory!.quoted)\n"
        return UI.log(verbose: "\(title)$ \(string)".ANSI(.cyan)) {
            self.shell.logOutputStringBlock = { self.logOutputString($0) }
            self.shell.logErrorStringBlock = { self.logErrorString($0) }
            UI.runningCMDs.append(self)
            defer {
                self.shell.logOutputStringBlock = nil
                self.shell.logErrorStringBlock = nil
                UI.runningCMDs.removeAll { $0 === self }
            }
            var environment = ProcessInfo.processInfo.environment
            environment.mergeEnvironment(env: self.env)
            if let env = env {
                environment.mergeEnvironment(env: env)
            }
            MBInputHandler.shared.addDelegate(self.shell)
            defer {
                MBInputHandler.shared.removeDelegate(self.shell)
            }
            return self.shell.executeCommand(string, inWorkingDirectory: workingDirectory, env: environment)
        }
    }

    public func logOutputString(_ string: String!) {
        if showOutput {
            UI.log(info: string, newLine: false)
        } else {
            UI.log(verbose: string, newLine: false)
        }
    }

    public func logErrorString(_ string: String!) {
        if showOutput {
            UI.log(info: string, newLine: false)
        } else {
            UI.log(verbose: string, newLine: false)
        }
    }

    public func cancel() {
        shell.cancel()
    }

    public static func executableExists(_ executable: String, env: [String: String]? = nil) -> Bool {
        if executable.isAbsolutePath {
            return executable.isExists
        }
        let cmd = MBCMD()
        if let env = env {
            cmd.env = env
        }
        return cmd.exec("which \(executable.split(separator: " ").first!)") == 0
    }

    public static var status: Bool = false

    public static func installZSHAutocompletion() throws {
        for name in ["mbox", "mdev"] {
            guard let shellPath = MBoxCore.bundle.path(forResource: "Autocompletion/\(name)", ofType: "sh") else { return }
            let zshPluginPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".oh-my-zsh").path
            guard zshPluginPath.isDirectory else {
                throw UserError("Could not find the `~/.oh-my-zsh`.")
            }
            var targetPath = zshPluginPath.appending(pathComponent: "custom/plugins/\(name)")
            if !FileManager.default.fileExists(atPath: targetPath) {
                UI.log(verbose: "Create directory `\(targetPath)`")
                try FileManager.default.createDirectory(atPath: targetPath, withIntermediateDirectories: true, attributes: nil)
            }
            targetPath = targetPath.appending(pathComponent: "_\(name)")
            if targetPath.isExists {
                UI.log(verbose: "Remove `\(targetPath)`")
                try FileManager.default.removeItem(atPath: targetPath)
            }
            UI.log(verbose: "Link `\(targetPath)` -> `\(shellPath)`")
            try FileManager.default.createSymbolicLink(atPath: targetPath, withDestinationPath: shellPath)
        }
        // Remove zcompdump cache
        for file in FileManager.default.homeDirectoryForCurrentUser.path.subFiles {
            if file.lastPathComponent.starts(with: ".zcompdump") {
                UI.log(verbose: "remove `\(file)`") {
                    try? FileManager.default.removeItem(atPath: file)
                }
            }
        }
    }

    public static func installCommandLine(binDir: String) throws {
        if !FileManager.default.fileExists(atPath: binDir) {
            let cmd = MBCMD()
            try cmd.sudoExec("mkdir -p '\(binDir)' && chown -R '\(NSUserName())' '\(binDir)'",
                             prompt: "MBox will create the directory `\(binDir)`.\nAdmin Password:")
        } else if !FileManager.default.isWritableFile(atPath: binDir) {
            let cmd = MBCMD()
            try cmd.sudoExec("chown -R '\(NSUserName())' '\(binDir)'",
                             prompt: "`\(binDir)` is not writable，MBox will change the ownership to your user!\nAdmin Password:")
        }
        try installCommandLine("mbox", binDir: binDir, scriptName: "MBoxCLI")
        try installCommandLine("mdev", binDir: binDir, scriptName: "MDevCLI")
    }

    private static func installCommandLine(_ binName: String, binDir: String, scriptName: String) throws {
        let cmdPath = binDir.appending(pathComponent: binName)
        let exePath = MBoxCore.bundle.bundlePath.deletingLastPathComponent.appending(pathComponent: scriptName)
        if let destPath = cmdPath.destinationOfSymlink {
            if destPath == exePath {
                return
            }
        }
        if cmdPath.isExists {
            UI.log(verbose: "Remove `\(cmdPath)`")
            try FileManager.default.removeItem(atPath: cmdPath)
        }
        UI.log(verbose: "Link `\(cmdPath)` -> `\(exePath)`")
        try FileManager.default.createSymbolicLink(atPath: cmdPath, withDestinationPath: exePath)
    }

    public static func installCommandLineAlias() throws {
        let supportFile = MBoxCore.bundle.bundleURL.deletingLastPathComponent().appendingPathComponent("sourced.sh").path
        let rcPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mboxrc")
        var resolved = false
        let string = "[[ -s \"\(supportFile)\" ]] && source \"\(supportFile)\" # MBox"
        var content = ""
        if rcPath.path.isFile {
            content = try String(contentsOf: rcPath)
            let regex = try NSRegularExpression(pattern: "^.*? source .*?/mbox\\.sh\".*$", options: .anchorsMatchLines)
            if let index = regex.firstMatch(in: content, range: NSRange(location: 0, length: content.count)) {
                let range = Range(index.range, in: content)
                content.replaceSubrange(range!, with: string)
                resolved = true
            }
        }
        if !resolved {
            if !content.hasSuffix("\n") {
                content.append("\n")
            }
            if !content.hasSuffix("\n\n") {
                content.append("\n")
            }
            content.append(string)
            content.append("\n")
        }
        UI.log(verbose: "Update `\(rcPath)`")
        try content.write(to: rcPath, atomically: true, encoding: .utf8)
    }
}
