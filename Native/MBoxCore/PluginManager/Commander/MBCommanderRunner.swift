//
//  MBCommanderRunner.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/7/6.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
import ObjCCommandLine

public var command: MBCommander?
public var cmdClass: MBCommander.Type = MBCommanderGroup.shared.command!
public var cmdGroup: MBCommanderGroup = MBCommanderGroup.shared

private func setupSingal() {
    ignoreSignal(SIGTTOU)
    trapSignal(.Crash) { signal in
        resetSTDIN()
        UI.logger.consoleLogger?.disabeRawMode()
        UI.indents.removeAll()
        Thread.callStackSymbols.forEach{
            UI.log(info: $0)
        }

        let signalName = "Receive Signal: \(String(cString: strsignal(signal)))"
        UI.log(summary: signalName)
        exitApp(signal, wait: false)
    }
    trapSignal(.Cancel) { signal in
        resetSTDIN()
        UI.logger.consoleLogger?.disabeRawMode()
        let signalName = "[Cancel] \(String(cString: strsignal(signal)))"
        UI.log(summary: signalName.ANSI(.red))
        let error = NSError(domain: "Signal",
                            code: Int(signal),
                            userInfo: [NSLocalizedDescriptionKey: signalName])
        let code = finish(signal, error: error)
        exitApp(code)
    }
}

private func logCommander(parser: ArgumentParser) {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    UI.log(info: "[\(formatter.string(from: MBProcess.shared.beginTime))] \(parser.rawDescription)", pip: .FILE)
}

private var sessionTitle: String? {
    var logNames = [String]()
    for arg in CommandLine.arguments.dropFirst() {
        if arg.hasPrefix("-") || arg.count > 20 { break }
        logNames.append(arg)
    }
    return logNames.isEmpty ? nil : logNames.joined(separator: " ")
}

public func exitApp(_ exitCode: Int32, wait: Bool = true) {
    try? FileManager.default.removeItem(atPath: FileManager.temporaryDirectory)
    if wait {
        waitExit(exitCode)
    }
    exit(exitCode)
}

public func runCommander() {
    MBCMD.isCMDEnvironment = true

    var exitCode: Int32 = 0
    do {
        let code = try runCommander(CommandLine.arguments)
        if exitSignal != nil { return }
        exitSignal = 0
        exitCode = finish(code)
    } catch {
        if exitSignal != nil { return }
        exitSignal = 0
        exitCode = finish(UI.statusCode, error: error)
        if !(error is UserError),
           !(error is ArgumentError),
           let logFile = UI.logger.verbFilePath {
            UI.log(info: "The log was saved: `\(logFile)`")
        }
    }
    exitApp(exitCode)
}

private func clearMBoxEnvironment() {
    let info = ProcessInfo.processInfo
    guard info.environment.has(key: "MBox") else {
        return
    }
    let keepKeys = ["MBOX_CLI_PATH", "MBOX_DEV_ROOT"]
    info.removeEnvironment(name: "MBox")
    for (key, _) in info.environment {
        if key.hasPrefix("MBOX_"), !keepKeys.contains(key) {
            info.removeEnvironment(name: key)
        }
    }
}

public func runCommander(_ arguments: [String]) throws -> Int32 {
    let process = MBProcess.shared
    process.mainThread.title = sessionTitle

    setupSingal()

    storeSTDIN()
    defer {
        resetSTDIN()
    }

    clearMBoxEnvironment()

    if ProcessInfo.processInfo.environment["SUDO_USER"] != nil {
        print("[ERROR] Please not use `sudo`!")
        exit(254)
    }

    let parser = ArgumentParser(arguments: arguments)
    process.args = parser

    if parser.hasOption("api", shift: false),
       let api = try? MBLoggerAPIFormatter(string: parser.option(for: "api") ?? "json") {
        process.apiFormatter = api
    }

    if let root = try? parser.option(for: "root") {
        process.rootPath = root.expandingTildeInPath
    }
    if let home = try? parser.option(for: "home") {
        MBSetting.globalDir = home
    }
    if let exeName = ProcessInfo.processInfo.arguments.first?.lastPathComponent,
       exeName == "MDevCLI" || exeName == "mdev" {
        guard let path = try? parser.option(for: "dev-root") ??
                MBSetting.global.core?.devRoot,
              !path.isEmpty else {
            print("[ERROR] require configuration for `mbox config core.dev-root`.")
            exit(253)
        }
        if !path.isDirectory {
            print("[ERROR] `dev-root` is not directory.")
            exit(253)
        }
        process.devRoot = path.expandingTildeInPath
    }

    if parser.hasOption("no-logfile") {
        UI.logger.avaliablePipe = UI.logger.avaliablePipe.withoutFILE()
    } else if let logfile = try? parser.option(for: "logfile"),
              logfile.count > 0,
              logfile.deletingPathExtension.count > 0 {
        UI.setupFileLogger(filePath: logfile)
        UI.logger.customFilePath = true
    } else {
        UI.setupFileLogger()
    }

    MBProcess.shared.verbose = parser.hasOption("verbose") || parser.hasFlag("v")
    if parser.hasOption("async") {
        MBProcess.shared.allowAsync = true
    } else if parser.hasOption("disable-async") {
        MBProcess.shared.allowAsync = false
    }

    MBPluginManager.shared.loadAll()

    MBCommanderGroup.preParse(parser)

    _ = parser.argument()!  // Executable Name

    logCommander(parser: parser)

    var throwError: Error?

    do {
    
        MBPluginManager.shared.registerCommander()
        
        _ = try executeCommand(parser: parser)
    } catch let error as ArgumentError {
        let help = Help(command: cmdClass, group: cmdGroup, argv: parser)
        if MBProcess.shared.showHelp, MBProcess.shared.apiFormatter != .none {
            UI.log(api: help.APIDescription(format: MBProcess.shared.apiFormatter))
        } else {
            if !error.description.isEmpty {
                UI.log(info: error.description)
                UI.log(info: "", pip: .ERR)
                throwError = error
            }
            if case let .help(msg) = error, let msg = msg {
                UI.log(info: msg,
                       pip: .ERR)
            } else {
                UI.log(info: help.description,
                       pip: .ERR)
            }
        }
    } catch let error as RuntimeError {
        throwError = error
        if error.description.count > 0 {
            UI.log(error: error.description, output: false)
        }
    } catch let error as UserError {
        throwError = error
        if error.description.count > 0 {
            UI.log(error: error.description, output: false)
        }
    } catch let error as NSError {
        throwError = error
        let info: String
        if let reason = error.localizedFailureReason {
            info = "(code: \(error.code) reason: \(reason))"
        } else {
            info = "(code: \(error.code))"
        }
        UI.log(error: "Error: \(error.domain) \(info)\n\t\(error.localizedDescription)")
    } catch {
        throwError = error
        UI.log(error: "\("Unknown error occurred.")\n\t\(error.localizedDescription)")
    }

    if let error = throwError {
        throw error
    } else {
        return UI.statusCode
    }
}

dynamic
public func executeCommand(parser: ArgumentParser) throws -> String {
    if let group = MBCommanderGroup.shared.command(for: parser) {
        cmdGroup = group
    } else {
        _ = try cmdClass.init(argv: parser)
        throw ArgumentError.invalidCommand("Not found command `\(parser.rawArguments.dropFirst().first!)` (\(MBProcess.shared.rootPath))")
    }

    if let cmd = cmdGroup.command {
        cmdClass = cmd.forwardCommand ?? cmd
    } else {
        throw ArgumentError.invalidCommand(nil)
    }

    command = try cmdClass.init(argv: parser)
    try command?.performAction()
    return MBProcess.shared.showHelp ? "help.\(cmdClass.fullName)" : cmdClass.fullName
}

@discardableResult
dynamic public func finish(_ code: Int32, error: Error? = nil) -> Int32 {
    UI.logSummary()

    MBProcess.shared.endTimer()
    let duration = MBThread.durationFormatter.string(from: MBProcess.shared.beginTime, to: MBProcess.shared.endTime!)!
    UI.log(verbose: "==" * 20 + " " + duration + " " + "==" * 20, pip: .FILE)

    let error = MBProcess.shared.showHelp ? nil : error
    var exitCode: Int32 = 0
    if code != 0 {
        exitCode = code
    } else if let error = error {
        if let error = error as? RuntimeError {
            exitCode = error.code
        } else if let _ = error as? UserError {
            exitCode = 254
        } else {
            exitCode = Int32((error as NSError).code)
        }
    }

    return exitCode
}

dynamic
public func waitExit(_ code: Int32) {
    UI.logger.wait(close: true)
}
