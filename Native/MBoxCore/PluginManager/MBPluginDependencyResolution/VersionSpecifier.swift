//
//  VersionSpecifier.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//


import Foundation


/// Describes which versions are acceptable for satisfying a dependency
/// requirement.
enum VersionSpecifier: Hashable {
    /**版本范围可能格式：
     1.
        不指定版本号，任何版本都可以。会默认选取最新版本
     
     2.
        '1.0' 表明版本号指定为1.0
     
     3. 指定版本范围
         '>= 0.1' 0.1以上，包括0.1
         
        当主版本号为0时，'~> 0.1.2' 0.2以下(不含0.2)，0.1.2以上（含0.1.2），这个基于次版本号比较。
        当主版本号不为0时，'~>1.0' 表明版本号为1.0<=x<2.0，这个基于主版本号比较。
     
    4. 引入依赖库指定的分支或节点
            引入master分支（默认）
                'AFNetworking', :git => 'https://github.com/gowalla/AFNetworking.git'
            引入指定的分支
                'AFNetworking', :git => 'https://github.com/gowalla/AFNetworking.git', :branch => 'dev'
            引入某个节点的代码
                'AFNetworking', :git => 'https://github.com/gowalla/AFNetworking.git', :tag => '0.7.0'
            引入某个特殊的提交节点
                'AFNetworking', :git => 'https://github.com/gowalla/AFNetworking.git', :commit => '082f8319af'
     */
    
    /**
        不指定版本号，任何版本都可以
     */
    case any
    /**
        指定具体版本号
     */
    case exactly(SemanticVersion)
    /**
        指定版本范围 >=
     */
    case atLeast(SemanticVersion)
    /**
        指定版本范围 ~>
                当主版本号为0时，'~> 0.1.2' 0.2以下(不含0.2)，0.1.2以上（含0.1.2），这个基于次版本号比较。
                当主版本号不为0时，'~>1.0' 表明版本号为1.0<=x<2.0，这个基于主版本号比较。
     */
    case compatibleWith(SemanticVersion)

    /**
     引入依赖库指定的分支或节点
     */
    case gitReference(String)

    //确定给定的固定版本是否满足这个版本范围。
    func isSatisfied(by version: PinnedVersion) -> Bool {
        
        func withSemanticVersion(_ predicate: (SemanticVersion) -> Bool) -> Bool {
            
            //从PinnedVersion变成SemanticVersion类型
            if let semanticVersion = SemanticVersion.from(version).value {
                return predicate(semanticVersion)
            } else {
                // Consider non-semantic versions (e.g., branches) to meet every
                // version range requirement
                return true
            }
        }

        switch self {
        case .any:
            return withSemanticVersion { !$0.isPreRelease }
        case .gitReference:
            return true
        case let .exactly(requirement):
            return withSemanticVersion { $0 == requirement }
            
        case let .atLeast(requirement):
            return withSemanticVersion { version in
                /**
                    判断给定的固定版本是否>=版本范围中的最小值
                 */
                let versionIsNewer = version >= requirement
                
                //只有当需求也是相同版本的预发布版本时，才选择预发布版本,否则返回false表示不满足范围
                let notPreReleaseOrSameComponents =    !version.isPreRelease
                    || (requirement.isPreRelease && version.hasSameNumericComponents(version: requirement))
                return notPreReleaseOrSameComponents && versionIsNewer
            }
        case let .compatibleWith(requirement):
            return withSemanticVersion { version in

                let versionIsNewer = version >= requirement
                let notPreReleaseOrSameComponents =    !version.isPreRelease
                    || (requirement.isPreRelease && version.hasSameNumericComponents(version: requirement))

                //只有当需求也是相同版本的预发布版本时，才选择预发布版本，否则返回false表示不满足范围
                guard notPreReleaseOrSameComponents else {
                    return false
                }

                // According to SemVer, any 0.x.y release may completely break the
                // exported API, so it's not safe to consider them compatible with one
                // another. Only patch versions are compatible under 0.x, meaning 0.1.1 is
                // compatible with 0.1.2, but not 0.2. This isn't according to the SemVer
                // spec but keeps ~> useful for 0.x.y versions.
                if version.major == 0 {
                    return version.minor == requirement.minor && versionIsNewer
                }

                return version.major == requirement.major && versionIsNewer
            }
        }
    }
}


extension VersionSpecifier: Scannable {
    /// Attempts to parse a VersionSpecifier.
    static func from(_ scanner: Scanner) -> Result<VersionSpecifier, ScannableError> {
        if scanner.scanString("==") != nil {
            return SemanticVersion.from(scanner).map { .exactly($0) }
        } else if scanner.scanString(">=") != nil {
            return SemanticVersion.from(scanner).map { .atLeast($0) }
        } else if scanner.scanString("~>") != nil {
            return SemanticVersion.from(scanner).map { .compatibleWith($0) }
        } else if scanner.scanString("\"") != nil {

            guard let refName = scanner.scanUpToString("\"") else {
                return .failure(ScannableError(message: "expected Git reference name", currentLine: scanner.currentLine))
            }
            
            if scanner.scanString("\"") == nil {
                return .failure(ScannableError(message: "unterminated Git reference name", currentLine: scanner.currentLine))
            }

            return .success(.gitReference(refName))
            
            
//            var refName: NSString?
//            if !scanner.scanUpTo("\"", into: &refName) || refName == nil {
//                return .failure(ScannableError(message: "expected Git reference name", currentLine: scanner.currentLine))
//            }
//
//            if scanner.scanString("\"") == nil {
//                return .failure(ScannableError(message: "unterminated Git reference name", currentLine: scanner.currentLine))
//            }
//
//            return .success(.gitReference(refName! as String))
//
            
        } else {
            return .success(.any)
        }
    }
}


extension VersionSpecifier: CustomStringConvertible {
    var description: String {
        switch self {
        case .any:
            return ""

        case let .exactly(version):
            return "== \(version)"

        case let .atLeast(version):
            return ">= \(version)"

        case let .compatibleWith(version):
            return "~> \(version)"

        case let .gitReference(refName):
            return "\"\(refName)\""
        }
    }
}


/**
        返回两个版本范围的交集
 */
func intersection(_ lhs: VersionSpecifier, _ rhs: VersionSpecifier) -> VersionSpecifier? { // swiftlint:disable:this cyclomatic_complexity
    switch (lhs, rhs) {
    // Unfortunately, patterns with a wildcard _ are not considered exhaustive,
    // so do the same thing manually. – swiftlint:disable:this vertical_whitespace_between_cases
    case (.any, .any), (.any, .exactly):
        return rhs

    case let (.any, .atLeast(rv)):
        return .atLeast(rv.discardingBuildMetadata)

    case let (.any, .compatibleWith(rv)):
        return .compatibleWith(rv.discardingBuildMetadata)

    case (.exactly, .any):
        return lhs

    case let (.compatibleWith(lv), .any):
        return .compatibleWith(lv.discardingBuildMetadata)

    case let (.atLeast(lv), .any):
        return .atLeast(lv.discardingBuildMetadata)

    case (.gitReference, .any), (.gitReference, .atLeast), (.gitReference, .compatibleWith), (.gitReference, .exactly):
        return lhs

    case (.any, .gitReference), (.atLeast, .gitReference), (.compatibleWith, .gitReference), (.exactly, .gitReference):
        return rhs

    case let (.gitReference(lv), .gitReference(rv)):
        if lv != rv {
            return nil
        }

        return lhs

    case let (.atLeast(lv), .atLeast(rv)):
        return .atLeast(max(lv.discardingBuildMetadata, rv.discardingBuildMetadata))

    case let (.atLeast(lv), .compatibleWith(rv)):
        return intersection(atLeast: lv.discardingBuildMetadata, compatibleWith: rv.discardingBuildMetadata)

    case let (.atLeast(lv), .exactly(rv)):
        return intersection(atLeast: lv.discardingBuildMetadata, exactly: rv)

    case let (.compatibleWith(lv), .atLeast(rv)):
        return intersection(atLeast: rv.discardingBuildMetadata, compatibleWith: lv.discardingBuildMetadata)

    case let (.compatibleWith(lv), .compatibleWith(rv)):
        if lv.major != rv.major {
            return nil
        }

        // According to SemVer, any 0.x.y release may completely break the
        // exported API, so it's not safe to consider them compatible with one
        // another. Only patch versions are compatible under 0.x, meaning 0.1.1 is
        // compatible with 0.1.2, but not 0.2. This isn't according to the SemVer
        // spec but keeps ~> useful for 0.x.y versions.
        if lv.major == 0 && rv.major == 0 {
            if lv.minor != rv.minor {
                return nil
            }
        }

        return .compatibleWith(max(lv.discardingBuildMetadata, rv.discardingBuildMetadata))

    case let (.compatibleWith(lv), .exactly(rv)):
        return intersection(compatibleWith: lv.discardingBuildMetadata, exactly: rv)

    case let (.exactly(lv), .atLeast(rv)):
        return intersection(atLeast: rv.discardingBuildMetadata, exactly: lv)

    case let (.exactly(lv), .compatibleWith(rv)):
        return intersection(compatibleWith: rv.discardingBuildMetadata, exactly: lv)

    case let (.exactly(lv), .exactly(rv)):
        if lv != rv {
            return nil
        }

        return lhs
    }
}

/**
        辅助函数：返回atLeast和compatibleWith的交集
 */
private func intersection(atLeast: SemanticVersion, compatibleWith: SemanticVersion) -> VersionSpecifier? {
    if atLeast.major > compatibleWith.major {
        return nil
    } else if atLeast.major < compatibleWith.major {
        return .compatibleWith(compatibleWith)
    } else {
        return .compatibleWith(max(atLeast, compatibleWith))
    }
}

/**
        辅助函数：返回atLeast和exactly的交集
 */
private func intersection(atLeast: SemanticVersion, exactly: SemanticVersion) -> VersionSpecifier? {
    if atLeast > exactly {
        return nil
    }

    return .exactly(exactly)
}

/**
        辅助函数：返回compatibleWith和exactly的交集
 */
private func intersection(compatibleWith: SemanticVersion, exactly: SemanticVersion) -> VersionSpecifier? {
    if exactly.major != compatibleWith.major || compatibleWith > exactly {
        return nil
    }
    
    //TODO 是否需要修改
    if exactly.major == 0 && compatibleWith.major == 0 {
        if exactly.minor != exactly.minor {
            return nil
        }
    }

    return .exactly(exactly)
}



///// Attempts to determine a version specifier that accurately describes the
///// intersection between the given specifiers.
/////
///// In other words, any version that satisfies the returned specifier will
///// satisfy _all_ of the given specifiers.
//func intersection<S: Sequence>(_ specs: S) -> VersionSpecifier? where S.Iterator.Element == VersionSpecifier {
//    return specs.reduce(nil) { (left: VersionSpecifier?, right: VersionSpecifier) -> VersionSpecifier? in
//        if let left = left {
//            return intersection(left, right)
//        } else {
//            return right
//        }
//    }
//}


