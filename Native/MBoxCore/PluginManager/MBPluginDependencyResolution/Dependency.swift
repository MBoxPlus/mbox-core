//
//  Dependency.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

/// Uniquely identifies a project that can be used as a dependency.
struct Dependency: Hashable {

    /// The unique, user-visible name for this project.
    var name: String

    var rootName: String

    init(_ name: String, rootName: String? = nil) {
        self.name = name
        self.rootName = rootName ?? name
    }
    
}


extension Dependency: Comparable {
    static func < (_ lhs: Dependency, _ rhs: Dependency) -> Bool {
        return lhs.name.caseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}


extension Dependency: CustomStringConvertible {
    var description: String {
            return name
    }
}
