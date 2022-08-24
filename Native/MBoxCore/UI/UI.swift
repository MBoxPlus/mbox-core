//
//  UI.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/6/14.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
import Yams

public var UI: MBThread { return MBThread.current }

extension MBThread {

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

    func indentLog<T>(flag: MBLogFlag, pip: MBLoggerPipe? = nil, block: () throws -> T) rethrows -> T {
        let pip = pip ?? self.indents.last?.pip ?? .OUT
        self.indents.append((flag: flag, pip: pip))
        defer {
            if !self.indents.isEmpty {
                self.indents.removeLast()
            }
        }
        return try block()
    }
}

extension MBThread {

    public func gets(prompt: String,
                     hint: ((String) -> String?)? = nil) throws -> String {
        let ln = LineNoise(terminal: self.terminal!)
        guard ln.mode == .supportedTTY else {
            throw RuntimeError("Query user in non-interactive shell is allowed.")
        }
        if let hint = hint {
            ln.setHintsCallback { currentBuffer in
                guard let value = hint(currentBuffer)?.dropFirst(currentBuffer.count) else { return (nil, nil) }
                return (String(value), (127, 0, 127))
            }
        }
        let prompt = prompt.ANSI(.yellow) + " "
        UI.log(info: prompt, newLine: false)
        let input = try ln.getLine(prompt: "").trimmingCharacters(in: .whitespacesAndNewlines)
        log(info: input, pip: .FILE)
        return input
    }

    public func gets(_ message: String,
                     default: String? = nil,
                     items: [String] = [],
                     hint: ((String) -> String?)? = nil) throws -> String {
        let mappedItems = items.map { (name: $0, value: $0) }
        if let defaultValue = `default` {
            return try gets(message, default: (name: defaultValue, value: defaultValue), items: mappedItems, hint: hint)
        } else {
            return try gets(message, default: nil, items: mappedItems, hint: hint)
        }
    }

    public func gets(_ message: String,
                     default: (name: String, value: String)?,
                     items: [(name: String, value: String)] = [],
                     hint: ((String) -> String?)? = nil) throws -> String {
        let prompt: String
        if items.count > 0 {
            let items = items.map { (item) -> (name: String, value: String) in
                var v = item
                if `default`?.value.lowercased() == v.value.lowercased() {
                    v.name = v.name.ANSI(.underline)
                }
                return v
            }
            prompt = "\(message) [\(items.map { $0.name }.joined(separator: "/"))]"
        } else if let value = `default` {
            prompt = "\(message) [\(value.name.ANSI(.underline))]"
        } else {
            prompt = message
        }
        var shortItems = items.map { $0.value.first!.lowercased() }
        if Set(shortItems).count != shortItems.count {
            shortItems = []
        }
        let hint2 = { (input: String) -> String? in
            if input.isEmpty, let defaultValue = `default`?.name {
                return defaultValue
            }
            if let hint = hint {
                return hint(input)
            }
            return items.first { $0.name.hasPrefix(input) }?.name
        }
        while true {
            var value = try gets(prompt: prompt, hint: hint2)
            if value.count == 0 {
                value = `default`?.value ?? ""
            }
            if value.count != 0 {
                if items.count > 0 {
                    if let first = items.first(where: {
                        if value.count == 1 {
                            return $0.value.first?.lowercased() == value.lowercased()
                        } else {
                            return $0.value.lowercased() == value.lowercased()
                        }
                    }) {
                        return first.value
                    }
                } else {
                    return value
                }
            }
        }
    }

    public func gets(_ message: String, default: Bool? = nil) throws -> Bool {
        let items = ["yes", "no"]
        let defaultValue: String?
        if let d = `default` {
            defaultValue = d ? "yes" : "no"
        } else {
            defaultValue = nil
        }
        while true {
            let value = try gets(message, default: defaultValue, items: items)
            switch value {
            case "yes": return true
            case "no": return false
            default: break
            }
        }
    }

    public func gets<T: CustomStringConvertible>(_ message: String, items: [T]) throws -> T {
        if MBProcess.shared.fromGUI { throw RuntimeError("Could not read stdin in App.") }
        for (index, item) in items.enumerated() {
            log(info: "\((index + 1).string.ANSI(.cyan)). \(item.description)")
        }
        while true {
            if let value = try gets(prompt: message).int,
               value > 0,
               value <= items.count {
                return items[value - 1]
            }
        }
    }

}

// MARK: - Log
extension MBThread {
    // MARK: API
    public func log(api: Any,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line,
                    formatter: MBLoggerAPIFormatter? = nil) {
        var formatter = formatter ?? MBProcess.shared.apiFormatter
        if formatter == .none {
            formatter = .yaml
        }
        let string: String
        switch formatter {
        case .json:
            if let json = api as? [String: Any] {
                string = json.toJSONString()!
            } else if let json = api as? [Any] {
                string = json.toJSONString()!
            } else {
                string = "\(api)"
            }
        case .plain:
            if let array = api as? [String] {
                string = array.joined(separator: "\n")
            } else {
                string = "\(api)"
            }
        case .yaml:
            do {
                string = try Yams.dump(object: api, sortKeys: true)
            } catch {
                self.log(error: error.localizedDescription)
                string = "\(api)"
            }
        default:
            string = "\(api)"
        }
        self.log(info: string, api: true, file: file, function: function, line: line)
    }

    // MARK: Verbose
    public func log(verbose: String,
                    pip: MBLoggerPipe? = nil,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line,
                    newLine: Bool = true) {
        logger.log(message: verbose, flag: .verbose, pip: pip, file: file, function: function, line: line, newLine: newLine)
    }

    public func log(verbose: String,
                    items: [String]?,
                    pip: MBLoggerPipe? = nil,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line) {
        log(verbose: verbose, pip: pip, file: file, function: function, line: line)
        guard let items = items else { return }
        for item in items {
            log(verbose: "- \(item)", pip: pip, file: file, function: function, line: line)
        }
    }

    @discardableResult
    public func log<T>(verbose: String,
                       items: [String]? = nil,
                       pip: MBLoggerPipe? = nil,
                       file: StaticString = #file,
                       function: StaticString = #function,
                       line: UInt = #line,
                       block: () throws -> T) rethrows -> T {
        log(verbose: verbose, items: items, pip: pip, file: file, function: function, line: line)
        return try self.indentLog(flag: .verbose, pip: pip) {
            return try block()
        }
    }

    @discardableResult
    public func log<T>(verbose: String,
                       resultOutput: (T) -> String?,
                       pip: MBLoggerPipe? = nil,
                       file: StaticString = #file,
                       function: StaticString = #function,
                       line: UInt = #line,
                       block: () throws -> T) rethrows -> T {
        log(verbose: verbose, pip: pip, file: file, function: function, line: line)
        return try self.indentLog(flag: .verbose, pip: pip) {
            let result = try block()
            if let r = resultOutput(result) {
                log(verbose: r, file: file, function: function, line: line)
            }
            return result
        }
    }

    // MARK: Info
    public func log(info: String,
                    items: [String]? = nil,
                    api: Bool = false,
                    pip: MBLoggerPipe? = nil,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line,
                    newLine: Bool = true) {
        let flag: MBLogFlag = api ? .api : .info
        logger.log(message: info, flag: flag, pip: pip, file: file, function: function, line: line, newLine: newLine)
        guard let items = items else { return }
        self.indentLog(flag: .info, pip: pip) {
            for item in items {
                var lines = item.split(separator: "\n")
                logger.log(message: "- \(lines.removeFirst())", flag: flag, file: file, function: function, line: line, newLine: newLine)
                for text in lines {
                    logger.log(message: "  \(text)", flag: flag, file: file, function: function, line: line, newLine: newLine)
                }
            }
        }
    }

    @discardableResult
    public func log<T>(info: String?,
                       pip: MBLoggerPipe? = nil,
                       file: StaticString = #file,
                       function: StaticString = #function,
                       line: UInt = #line,
                       block: () throws -> T) rethrows -> T {
        if let info = info {
            log(info: info, pip: pip, file: file, function: function, line: line)
        }
        return try self.indentLog(flag: .info, pip: pip) {
            return try block()
        }
    }

    // MARK: Warn
    public func log(warn: String,
                    items: [String]? = nil,
                    summary: Bool = true,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line) {
        let info = LogInfo(flag: .warning, message: warn, items: items, file: file, function: function, line: line)
        log(info: info, verbose: false)
        if summary {
            MBProcess.shared.addSummary(.warning, info: info)
        }
    }

    // MARK: Error
    public func log(error: String,
                    output: Bool = true,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line) {
        let info = LogInfo(flag: .error, message: error, file: file, function: function, line: line)
        log(info: info, verbose: false)
        MBProcess.shared.addSummary(.error, info: info)
    }

    // MARK: Section
    dynamic
    public func section(_ title: String,
                        file: StaticString = #file,
                        function: StaticString = #function,
                        line: UInt = #line) {
        if self.indents.isEmpty {
            self.title = title
        }
        let title = MBProcess.shared.verbose ? title.ANSI(.yellow) : title
        logger.log(message: title, flag: .info, file: file, function: function, line: line)
    }

    @discardableResult
    public func section<T>(_ title: String? = nil,
                           file: StaticString = #file,
                           function: StaticString = #function,
                           line: UInt = #line,
                           block: () throws -> T) rethrows -> T {
        if let title = title {
            section(title, file: file, function: function, line: line)
        }
        return try self.indentLog(flag: .info) {
            return try block()
        }
    }

    // MARK: Private
    func log(summary: String,
             file: StaticString = #file,
             function: StaticString = #function,
             line: UInt = #line) {
        let info = LogInfo(flag: .info, message: summary, file: file, function: function, line: line)
        MBProcess.shared.addSummary(.info, info: info)
    }

    func log(info: LogInfo, verbose: Bool = false) {
        logger.log(message: info.description,
                   flag: verbose ? .verbose : info.flag,
                   file: info.file,
                   function: info.function,
                   line: info.line)
    }

    func logSummary() {
        let process = MBProcess.shared
        if !process.infos.isEmpty {
            log(info: "")
            for info in process.infos {
                log(info: info)
            }
        }
        if !process.warnings.isEmpty {
            log(info: "")
            for warn in process.warnings {
                log(info: warn)
            }
        }
        if !process.errors.isEmpty {
            log(info: "")
            for error in process.errors {
                log(info: error)
            }
        }
    }
}
