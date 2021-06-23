//
//  String+Path.swift
//  MBox
//
//  Created by Whirlwind on 2018/8/21.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation

public enum FileExistence: Equatable {
    case none
    case file
    case directory
}

public extension String {
    func appending(pathComponent: String) -> String {
        return (self as NSString).appendingPathComponent(pathComponent)
    }

    func appending(pathExtension: String) -> String {
        return (self as NSString).appendingPathExtension(pathExtension)!
    }

    func appending(fileName: String) -> String {
        let dir = self.deletingLastPathComponent
        var name = self.lastPathComponent
        let ext = name.pathExtension
        name = name.deletingPathExtension.appending(fileName)
        return dir.appending(pathComponent: name).appending(pathExtension: ext)
    }

    var standardizingPath: String {
        return (self as NSString).standardizingPath
    }

    var expandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }

    var cleanPath: String {
        let relative = !self.isAbsolutePath
        var paths = [String]()
        for path in self.split(separator: "/") {
            if path == ".." {
                if paths.count > 0 && paths.last != ".." {
                    _ = paths.popLast()
                } else {
                    if relative {
                        paths.append("..")
                    }
                }
            } else if path != "." && path.count != 0 {
                paths.append(String(path))
            }
        }
        let newPath = paths.joined(separator: "/")
        if relative {
            return newPath
        } else {
            return "/\(newPath)"
        }
    }

    var isAbsolutePath: Bool {
        return (self as NSString).isAbsolutePath
    }

    var isExists: Bool {
        return exists != .none || isSymlink
    }

    var exists: FileExistence {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self, isDirectory: &isDirectory)

        switch (exists, isDirectory.boolValue) {
        case (false, _): return .none
        case (true, false): return .file
        case (true, true): return .directory
        }
    }

    var isDirectory: Bool {
        return exists == .directory
    }

    var isFile: Bool {
        return exists == .file
    }

    var isSymlink: Bool {
        do {
            let _ = try FileManager.default.destinationOfSymbolicLink(atPath: self)
            return true
        } catch {
            return false
        }
    }

    var destinationOfSymlink: String {
        var targetPath = self
        do {
            let symlink = try FileManager.default.destinationOfSymbolicLink(atPath: targetPath)
            if symlink.hasPrefix("/") {
                targetPath = symlink
            } else {
                targetPath = targetPath.deletingLastPathComponent.appending(pathComponent:symlink)
            }
        } catch {
            return self
        }
        return targetPath.standardizingPath
    }

    var subFiles: [String] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: self), includingPropertiesForKeys: [URLResourceKey.isRegularFileKey, URLResourceKey.isSymbolicLinkKey], options: []) else {
            return []
        }
        return urls.compactMap { url -> String? in
            if let isRegularFile = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isRegularFile {
                return url.path
            }
            if let isSymbolic = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink, isSymbolic {
                let path = url.path.destinationOfSymlink
                if path.isFile {
                    return url.path
                }
            }
            return nil
        }
    }

    var subDirectories: [String] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: self), includingPropertiesForKeys: [URLResourceKey.isDirectoryKey, URLResourceKey.isSymbolicLinkKey], options: []) else {
            return []
        }
        return urls.compactMap { url -> String? in
            if let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDirectory {
                return url.path
            }
            if let isSymbolic = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink, isSymbolic {
                let path = url.path.destinationOfSymlink
                if path.isDirectory {
                    return url.path
                }
            }
            return nil
        }
    }

    func relativePath(from base: String) -> String {
        // Remove/replace "." and "..", make paths absolute
        let destComponents = self.pathComponents
        let baseComponents = base.pathComponents

        // Find number of common path components
        var i = 0
        while i < destComponents.count && i < baseComponents.count
            && destComponents[i] == baseComponents[i] {
                i += 1
        }

        // Build relative path
        var relComponents = Array(repeating: "..", count: baseComponents.count - i)
        relComponents.append(contentsOf: destComponents[i...])
        return relComponents.joined(separator: "/")
    }

    func findExistFile(in files: [String]) -> String? {
        for file in files {
            let path = self.appending(pathComponent: file)
            if path.isFile {
                return file
            }
        }
        return nil
    }

    func findExistPath(in files: [String]) -> String? {
        guard let file = self.findExistFile(in: files) else { return nil }
        return self.appending(pathComponent: file)
    }
}
