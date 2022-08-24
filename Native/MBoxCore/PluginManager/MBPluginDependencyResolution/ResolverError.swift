//
//  ResolverError.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//



import Foundation

enum ResolverError: Error {
    typealias VersionRequirement = (specifier: VersionSpecifier, fromDependency: Dependency?)

    //对于一个依赖无法找到满足版本范围的固定版本
    case requiredVersionNotFound(Dependency, VersionSpecifier)
    
    //对依赖项给出了不兼容的版本范围
    case incompatibleRequirements(Dependency, VersionRequirement, VersionRequirement)
    
    //发生内部错误
    case internalError(description: String)
    
    //给定要更新的依赖项列表，没有找到有效的版本
    case unsatisfiableDependencyList([String])
    
    //无法找到该依赖项的固定版本
    case taggedVersionNotFound(Dependency)
    

}



private func == (_ lhs: ResolverError.VersionRequirement, _ rhs: ResolverError.VersionRequirement) -> Bool {
    return lhs.specifier == rhs.specifier && lhs.fromDependency == rhs.fromDependency
}

extension ResolverError: Equatable {
    static func == (_ lhs: ResolverError, _ rhs: ResolverError) -> Bool { // swiftlint:disable:this cyclomatic_complexity function_body_length
        switch (lhs, rhs) {
        case let (.incompatibleRequirements(left, la, lb), .incompatibleRequirements(right, ra, rb)):
            let specifiersEqual = (la == ra && lb == rb) || (la == rb && rb == la)
            return left == right && specifiersEqual
            
        case let (.taggedVersionNotFound(left), .taggedVersionNotFound(right)):
            return left == right

        case let (.requiredVersionNotFound(left, leftVersion), .requiredVersionNotFound(right, rightVersion)):
            return left == right && leftVersion == rightVersion

        case let (.unsatisfiableDependencyList(left), .unsatisfiableDependencyList(right)):
            return left == right
            
        case let (.internalError(left), .internalError(right)):
            return left == right
            
        default:
            return false
        }
    }
}

extension ResolverError: CustomStringConvertible {
    var description: String {
        switch self {
        case let .incompatibleRequirements(dependency, first, second):
            let requirement: (VersionRequirement) -> String = { arg in
                let (specifier, fromDependency) = arg
                return "\(specifier)" + (fromDependency.map { " (\($0))" } ?? "")
            }
            return "Could not pick a version for \(dependency), due to mutually incompatible requirements:\n\t\(requirement(first))\n\t\(requirement(second))"
        
        case let .taggedVersionNotFound(dependency):
            return "No tagged versions found for \(dependency)"
            
        case let .requiredVersionNotFound(dependency, specifier):
            return "No available version for \(dependency) satisfies the requirement: \(specifier)"

        case let .unsatisfiableDependencyList(subsetList):
            let subsetString = subsetList.map { "\t" + $0 }.joined(separator: "\n")
            return "No valid versions could be found that restrict updates to:\n\(subsetString)"

        case let .internalError(description):
            return description
        }
    }
}


/// Error parsing strings into types, used in Scannable protocol
struct ScannableError: Error, Equatable {
    let message: String
    let currentLine: String?

    init(message: String, currentLine: String? = nil) {
        self.message = message
        self.currentLine = currentLine
    }
}

extension ScannableError: CustomStringConvertible {
    var description: String {
        return currentLine.map { "\(message) in line: \($0)" } ?? message
    }
}
