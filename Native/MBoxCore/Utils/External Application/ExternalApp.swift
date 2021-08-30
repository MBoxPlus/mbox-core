//
//  ExternalApplicationProtocol.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/3.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation
import AppKit

open class ExternalApp {
    public static let shared = ExternalApp()

    public init(name: String? = nil) {
        self.name = name
    }

    open var name: String?

    open var path: String? {
        guard let name = self.name else { return nil }
        return Self.path(forApplication: name)
    }

    open var installed: Bool {
        guard let name = self.name else { return true }
        return Self.installed(forApplication: name)
    }

    @discardableResult
    open func open(directory: String) -> Bool {
        return open(directories: [directory])
    }

    @discardableResult
    open func open(directories: [String]) -> Bool {
        return self.log(files: directories) {
            return NSWorkspace.shared.openFiles(directories, withApplication: name)
        }
    }

    @discardableResult
    public static func open(url: URL) -> Bool {
        return NSWorkspace.shared.open(url)
    }

    @discardableResult
    public static func open(file: String) -> Bool {
        return NSWorkspace.shared.openFile(file)
    }

    @discardableResult
    open func open(url: URL) -> Bool {
        return self.log(files: [url.isFileURL ? url.path : url.absoluteString]) {
            return NSWorkspace.shared.openURLs([url], withApplication: name)
        }
    }

    @discardableResult
    open func open(file: String) -> Bool {
        return open(files: [file])
    }

    @discardableResult
    open func open(files: [String]) -> Bool {
        return self.log(files: files) {
            return NSWorkspace.shared.openFiles(files, withApplication: name)
        }
    }

    public static func installed(forApplication: String) -> Bool {
        return path(forApplication: forApplication) != nil
    }

    public static func path(forApplication: String) -> String? {
        return NSWorkspace.shared.fullPath(forApplication: forApplication)
    }

    @discardableResult
    private func log(files: [String],
                     file: StaticString = #file,
                     function: StaticString = #function,
                     line: UInt = #line,
                     block: () throws -> Bool) rethrows -> Bool {
        var message: String
        if let name = self.name, !name.isEmpty {
            message = "\(name) open"
        } else {
            message = "Open"
        }
        let items: [String]?
        if files.count == 1 {
            message.append(" `\(files.first!)`")
            items = nil
        } else {
            message.append(":")
            items = files
        }
        UI.log(info: message, items: items, file: file, function: function, line: line)
        return try block()
    }
}
