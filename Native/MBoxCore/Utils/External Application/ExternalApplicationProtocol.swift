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
    public init(name: String? = nil) {
        self.name = name
    }

    open var name: String?

    open var path: String? {
        guard let name = self.name else { return nil }
        return Self.path(forApplication: name)
    }

    open var installed: Bool {
        guard let name = self.name else { return false }
        return Self.installed(forApplication: name)
    }

    @discardableResult
    open func open(directory: String) -> Bool {
        return open(directories: [directory])
    }

    @discardableResult
    open func open(directories: [String]) -> Bool {
        return NSWorkspace.shared.openFiles(directories, withApplication: name)
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
        return NSWorkspace.shared.openURLs([url], withApplication: name)
    }

    @discardableResult
    open func open(file: String) -> Bool {
        return open(files: [file])
    }

    @discardableResult
    open func open(files: [String]) -> Bool {
        return NSWorkspace.shared.openFiles(files, withApplication: name)
    }

    public static func installed(forApplication: String) -> Bool {
        return path(forApplication: forApplication) != nil
    }

    public static func path(forApplication: String) -> String? {
        return NSWorkspace.shared.fullPath(forApplication: forApplication)
    }

//    public static func selectPrefectApplication<T: ExternalApplication>(_ prefect: String?, inApplictions: [T.Type]) -> T.Type? {
//        if let prefect = prefect,
//            let app = inApplictions.first(where: { $0.name == prefect }),
//            app.installed {
//            return app
//        }
//        for app in inApplictions {
//            if app.installed {
//                return app
//            }
//        }
//        return nil
//    }
}

let MBoxGUI = ExternalApp(name: "mbox")
