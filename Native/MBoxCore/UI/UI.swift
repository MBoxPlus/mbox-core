//
//  UI.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/6/14.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
import CocoaLumberjack
import Yams

public var UI: MBSession { return MBSession.current! }

extension MBSession {

    internal func indentLog<T>(flag: DDLogFlag, block: () throws -> T) rethrows -> T {
        self.indents.append(flag)
        defer {
            if !self.indents.isEmpty {
                self.indents.removeLast()
            }
        }
        return try block()
    }

    open func gets() -> String {
        let value = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        log(info: value, pip: .FILE)
        return value
    }

    open func gets(_ message: String, default: String? = nil, items: [String] = []) -> String {
        let mappedItems = items.map { (name: $0, value: $0) }
        if let defaultValue = `default` {
            return gets(message, default: (name: defaultValue, value: defaultValue), items: mappedItems)
        } else {
            return gets(message, default: nil, items: mappedItems)
        }
    }

    open func gets(_ message: String, default: (name: String, value: String)?, items: [(name: String, value: String)] = []) -> String {
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
        while true {
            log(info: prompt.ANSI(.yellow) + " ", newLine: false)
            var value = gets()
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

    open func gets(_ message: String, default: Bool? = nil) -> Bool {
        let items = ["yes", "no"]
        let defaultValue: String?
        if let d = `default` {
            defaultValue = d ? "yes" : "no"
        } else {
            defaultValue = nil
        }
        while true {
            let value = gets(message, default: defaultValue, items: items)
            switch value {
            case "yes": return true
            case "no": return false
            default: break
            }
        }
    }

    open func gets<T: CustomStringConvertible>(_ message: String, items: [T]) throws -> T {
        if UI.fromGUI { throw RuntimeError("Could not read stdin in App.") }
        for (index, item) in items.enumerated() {
            log(info: "\((index + 1).string.ANSI(.cyan)). \(item.description)")
        }
        while true {
            log(info: message.ANSI(.cyan) + " ", newLine: false)
            if let value = gets().int,
               value > 0,
               value <= items.count {
                return items[value - 1]
            }
        }
    }

    // MARK: log
    open func log(api: Any,
                  file: StaticString = #file,
                  function: StaticString = #function,
                  line: UInt = #line,
                  formatter: MBLoggerAPIFormatter? = nil) {
        var formatter = formatter ?? self.apiFormatter
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

    open func log(verbose: String,
                  pip: MBLoggerPipe? = nil,
                  file: StaticString = #file,
                  function: StaticString = #function,
                  line: UInt = #line,
                  newLine: Bool = true) {
        logger.log(message: verbose, session: self, level: .verbose, flag: .verbose, pip: pip ?? self.defaultPipe, file: file, function: function, line: line, newLine: newLine)
    }

    open func log(info: String,
                  items: [String]? = nil,
                  api: Bool = false,
                  pip: MBLoggerPipe? = nil,
                  file: StaticString = #file,
                  function: StaticString = #function,
                  line: UInt = #line,
                  newLine: Bool = true) {
        let level: DDLogLevel = api ? .all : .info
        let flag: DDLogFlag = api ? .api : .info
        logger.log(message: info, session: self, level: level, flag: flag, pip: pip ?? self.defaultPipe, file: file, function: function, line: line, newLine: newLine)
        if let items = items {
            self.indentLog(flag: flag) {
                for item in items {
                    logger.log(message: "- \(item)", session: self, level: level, flag: flag, file: file, function: function, line: line, newLine: newLine)
                }
            }
        }
    }

    open func log(warn: String,
                  items: [String]? = nil,
                  summary: Bool = true, // 是否汇总在最后显示
                  file: StaticString = #file,
                  function: StaticString = #function,
                  line: UInt = #line) {
        let info = LogInfo(flag: .warning, message: warn, items: items, file: file, function: function, line: line)
        log(info: info, verbose: true)
        if summary {
            self.warnings << info
        }
    }

    open func log(error: String,
                  output: Bool = true,
                  file: StaticString = #file,
                  function: StaticString = #function,
                  line: UInt = #line) {
        let info = LogInfo(flag: .error, message: error, file: file, function: function, line: line)
        if output {
            log(info: info, verbose: true)
        }
        self.errors << info
    }

    @discardableResult
    open func log<T>(info: String?,
                     pip: MBLoggerPipe? = nil,
                     file: StaticString = #file,
                     function: StaticString = #function,
                     line: UInt = #line,
                     block: () throws -> T) rethrows -> T {
        if let info = info {
            log(info: info, pip: pip, file: file, function: function, line: line)
        }
        return try self.indentLog(flag: .info) {
            return try block()
        }
    }

    @discardableResult
    open func log<T>(verbose: String,
                     items: [String]? = nil,
                     file: StaticString = #file,
                     function: StaticString = #function,
                     line: UInt = #line,
                     block: () throws -> T) rethrows -> T {
        log(verbose: verbose, file: file, function: function, line: line)
        if let items = items {
            for item in items {
                log(verbose: "- \(item)", file: file, function: function, line: line)
            }
        }
        return try self.indentLog(flag: .verbose) {
            return try block()
        }
    }

    @discardableResult
    open func log<T>(verbose: String,
                     resultOutput: (T) -> String?,
                     file: StaticString = #file,
                     function: StaticString = #function,
                     line: UInt = #line,
                     block: () throws -> T) rethrows -> T {
        log(verbose: verbose, file: file, function: function, line: line)
        return try self.indentLog(flag: .verbose) {
            let result = try block()
            if let r = resultOutput(result) {
                log(verbose: r, file: file, function: function, line: line)
            }
            return result
        }
    }

    public func log(summary: String,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line) {
        let info = LogInfo(flag: .info, message: summary, file: file, function: function, line: line)
        self.infos << info
    }

    dynamic
    public func section(_ title: String,
                        file: StaticString = #file,
                        function: StaticString = #function,
                        line: UInt = #line) {
        if self.indents.isEmpty {
            self.title = title
        }
        let title = logger.verbose ? title.ANSI(.yellow) : title
        logger.log(message: title, session: self, level: .info, flag: .info, pip: self.defaultPipe, file: file, function: function, line: line)
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

    internal func log(info: LogInfo, verbose: Bool = false) {
        logger.log(message: info.description,
                   session: self,
                   level: verbose ? .verbose : .info,
                   flag: verbose ? .verbose : info.flag,
                   file: info.file,
                   function: info.function,
                   line: info.line)
    }

    internal func logSummary() {
        if !infos.isEmpty {
            log(info: "")
            for info in infos {
                log(info: info)
            }
        }
        if !warnings.isEmpty {
            log(info: "")
            for warn in warnings {
                log(info: warn)
            }
        }
        if !errors.isEmpty {
            log(info: "")
            for error in errors {
                log(info: error)
            }
        }
    }
}
