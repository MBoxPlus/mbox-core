//
//  FileManager+Path.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/12/2.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

var FileManagerTemporaryDirectoryKey: UInt8 = 0
extension FileManager {
    public class var temporaryDirectory: String {
        return associatedObject(base: self, key: &FileManagerTemporaryDirectoryKey) {
            let path = NSTemporaryDirectory().appending(pathComponent: "MBox").appending(pathComponent: NSUUID().uuidString)
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return path
        }
    }

    public class func temporaryPath(_ name: String? = nil, scope: String? = nil) -> String {
        var path = temporaryDirectory
        if let scope = scope {
            path = path.appending(pathComponent: scope)
        }
        if let name = name {
            return temporaryDirectory.appending(pathComponent: name)
        } else {
            return temporaryDirectory.appending(pathComponent: String.random(ofLength: 6))
        }
    }

    public class var supportDirectory: String {
        return self.supportDirectory(for: "MBox")
    }

    public class func supportDirectory(for name: String) -> String {
        let url = `default`.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(name)
        return url.path
    }

    public class func supportCachesDirectory(for name: String) -> String {
        return self.supportDirectory(for: "Caches/MBox").appending(pathComponent: name)
    }

    public class var home: String {
        return `default`.homeDirectoryForCurrentUser.path
    }

    public class var pwd: String {
        return `default`.currentDirectoryPath
    }

    @discardableResult
    public class func chdir(_ dir: String) -> Bool {
        return `default`.changeCurrentDirectoryPath(dir)
    }

    public class func chdir<T>(_ dir: String, block: () throws -> T) rethrows -> T {
        let pwd = self.pwd
        defer {
            `default`.changeCurrentDirectoryPath(pwd)
        }
        `default`.changeCurrentDirectoryPath(dir)
        return try block()
    }

    public class func mkdir_p(_ path: String) throws {
        try `default`.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }

    public class func mkdir(_ path: String) throws {
        try `default`.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
    }

    public class func lock(_ path: String) throws {
        try `default`.setAttributes([.immutable: true], ofItemAtPath: path)
    }

    public class func unlock(_ path: String) throws {
        try `default`.setAttributes([.immutable: false], ofItemAtPath: path)
    }

    public class func unlock(_ path: String, block: () throws -> Void) throws {
        let attr = try `default`.attributesOfItem(atPath: path)
        defer {
            try? `default`.setAttributes(attr, ofItemAtPath: path)
        }
        try unlock(path)
        try block()
    }
}
