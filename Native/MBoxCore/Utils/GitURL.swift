//
//  MBGitURL.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/24.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation

public struct MBGitURL: Equatable, CustomStringConvertible {
    public init?(_ git: __shared String) {
        guard let matchData = try? git.match(regex: "^((.*):\\/\\/)?((.*)@)?(.*?)(:(\\d+))?[:|\\/](.*)\\/(.*?)(.git)?$")?.first else {
            return nil
        }
        url = git
        scheme = matchData[2]
        user = matchData[4]
        host = matchData[5]
        port = matchData[7]
        groups = matchData[8].split(separator: "/").map { String($0) }
        project = matchData[9]

        if user.isEmpty {
            user = "git"
        }
    }

    public private(set) var url: String
    public private(set) var scheme: String
    public private(set) var host: String
    public private(set) var port: String
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
        var url = ""
        if !self.scheme.isEmpty, self.scheme.lowercased() != "https" {
            url.append(self.scheme + "://")
        }
        url.append("\(user)@\(host):")
        if !self.port.isEmpty  {
            url.append("\(port)/")
        }
        url.append("\(group)/\(project).git")
        return url
    }

    public func toHTTPStyle() -> String {
        var url = "https://"
        if self.user != "git" {
            url.append(self.user + "@")
        }
        url.append(host)
        if self.port.isEmpty {
            url.append("/")
        } else {
            url.append(":\(port)/")
        }
        url.append("\(group)/\(project).git")
        return url
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
