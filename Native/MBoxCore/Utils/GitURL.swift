//
//  MBGitURL.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/24.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation

extension String {
    public func match(_ regex: String) throws -> [[String]]? {
        let regex = try NSRegularExpression(pattern: regex, options: [])
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        if results.count == 0 {
            return nil
        }
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }

    public func isMatch(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
infix operator =~
public func =~(string:String, regex:String) -> Bool {
    return string.isMatch(regex)
}
infix operator !~
public func !~(string:String, regex:String) -> Bool {
    return !string.isMatch(regex)
}

public struct MBGitURL: Equatable, CustomStringConvertible {
    public init?(_ git: __shared String) {
        guard let matchData = try? git.match("^((.*):\\/\\/)?((.*)@)?(.*?)[:|\\/](.*)\\/(.*?)(.git)?$")?.first else {
            return nil
        }
        url = git
        scheme = matchData[2]
        user = matchData[4]
        host = matchData[5]
        groups = matchData[6].split(separator: "/").map { String($0) }
        project = matchData[7]

        if user.isEmpty {
            user = "git"
        }
    }

    public private(set) var url: String
    public private(set) var scheme: String
    public private(set) var host: String
    public private(set) var user: String
    public private(set) var groups: [String]
    public private(set) var project: String

    public var group: String {
        return groups.joined(separator: "/")
    }

    public var path: String {
        return "\(group)/\(project)"
    }

    public func toGitStyle() -> String {
        return "\(user)@\(host):\(group)/\(project).git"
    }

    public func toHTTPStyle() -> String {
        return "https://\(host)/\(group)/\(project).git"
    }

    public var description: String {
        return self.url
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.host.lowercased() == rhs.host.lowercased() &&
            lhs.group.lowercased() == rhs.group.lowercased() &&
            lhs.project.lowercased() == rhs.project.lowercased()
    }
}
