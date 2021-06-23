//
//  MBCache.swift
//  MBoxCore
//
//  Created by Yao Li on 2020/4/13.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation

public class MBCache {
    public static let shared = MBCache()

    private var dataMap: [String: Any] = [String: Any]()

    private var name: String
    private var directory: URL
    private let excutableFileName = ProcessInfo.processInfo.arguments.first?.lastPathComponent ?? "MBoxCLI"

    var cacheFileURL: URL {
        get {
            return self.directory.appendingPathComponent(excutableFileName).appendingPathComponent(self.name)
        }
        
    }

    init(name: String = "shared", directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!) {
        self.name = name
        self.directory = directory
        if FileManager.default.fileExists(atPath: self.cacheFileURL.path) {
            if let data = try? Data(contentsOf: self.cacheFileURL) {
                if let map = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any] {
                    self.dataMap = map
                }
            }
        }
    }

    public func set(date: Date, forKey key: String) {
        self.dataMap[key] = date
        self.dumpToDisk()
    }

    public func date(forKey key: String) -> Date? {
        return self.dataMap[key] as? Date
    }
    
    public func date(forKey key: String, defaultValue: Date) -> Date {
        if let date = self.dataMap[key] as? Date {
            return date
        } else {
            return defaultValue
        }
    }

    func dumpToDisk() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: dataMap, requiringSecureCoding: true)
            try data.write(to: self.cacheFileURL)
        } catch {

        }
    }
    
}
