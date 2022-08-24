//
//  SemanticVersion.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//


import Foundation



/// A semantic version.
/// - Note: See <http://semver.org/>
/**
    语义版本号由五个部分组成 主版本号、次版本号、补丁号、预发布版本标签 和 构建号。
 */
struct SemanticVersion: Hashable {
    /**1..
        主版本号
     /// Increments to this component represent incompatible API changes.
     */
    let major: Int
    /**2.
        次版本号
     /// Increments to this component represent backwards-compatible
     /// enhancements.
     */
    let minor: Int
    /**3.
        补丁号
     /// Increments to this component represent backwards-compatible bug fixes.
     */
    let patch: Int
    
    /**4.
        预发布版本标签
     /// Indicates that the version is unstable
     */
    let preRelease: String?
    /**5.
        构建号
     /// The build metadata
     /// Build metadata is ignored when comparing versions
     */
    let buildMetadata: String?

    /**
        版本组件的列表，按照从主版本号、次版本号、补丁号的顺序排列。
     */
    var components: [Int] {
        return [ major, minor, patch ]
    }
    
    /**
            判断是否是预发布版本
     */
    var isPreRelease: Bool {
        return self.preRelease != nil
    }

    init(_ major: Int, _ minor: Int, _ patch: Int, preRelease: String? = nil, buildMetadata: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
        self.buildMetadata = buildMetadata
    }
    
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(major)
        hasher.combine(minor)
        hasher.combine(patch)
    }
    
}


extension SemanticVersion {
    
    // 从PinnedVersion变成SemanticVersion类型
    static func from(_ pinnedVersion: PinnedVersion) -> Result<SemanticVersion, ScannableError> {
        let scanner = Scanner(string: pinnedVersion.commitish)

        // Skip leading characters, like "v" or "version-" or anything like
        // that.
        // 扫描到指定字符集合时停下，result是指定字符前面的字符串
        scanner.scanUpToCharacters(from: versionCharacterSet)

        //尝试从字符串扫描器中解析人类可读的格式“a.b.c”的SemanticVersion版本
        return self.from(scanner).flatMap { version in
            if scanner.isAtEnd {
                return .success(version)
            } else {
                return .failure(ScannableError(message: "syntax of version \"\(version)\" is unsupported", currentLine: scanner.currentLine))
            }
        }
    }
  
    /// Set of valid digts for SemVer versions
    /// - note: Please use this instead of `CharacterSet.decimalDigits`, as
    /// `decimalDigits` include more characters that are not contemplated in
    /// the SemVer spects (e.g. `FULLWIDTH` version of digits, like `４`)
    fileprivate static let semVerDecimalDigits = CharacterSet(charactersIn: "0123456789")

    //SemVer major.minor.patch区段的有效字符集
    fileprivate static let versionCharacterSet = CharacterSet(charactersIn: ".")
        .union(SemanticVersion.semVerDecimalDigits)

    fileprivate static let asciiAlphabeth = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    )

    /// Set of valid character for SemVer build metadata section
    fileprivate static let invalidBuildMetadataCharacters = asciiAlphabeth
        .union(SemanticVersion.semVerDecimalDigits)
        .union(CharacterSet(charactersIn: "-"))
        .inverted

    /// Separator of pre-release components
    fileprivate static let preReleaseComponentsSeparator = "."
    
    /// 除了构建号数据被丢弃，返回与self相同的SemanticVersion
    var discardingBuildMetadata: SemanticVersion {
        return SemanticVersion(self.major, self.minor, self.patch, preRelease: self.preRelease)
    }
    
    
    

}

extension SemanticVersion: Comparable {
    static func < (_ lhs: SemanticVersion, _ rhs: SemanticVersion) -> Bool {
        if lhs.components == rhs.components {
            return lhs.isPreReleaseLesser(preRelease: rhs.preRelease)
        }
        return lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}


extension SemanticVersion {

    /**
        假定两个版本的主版本号、次版本号、补丁号都相同；
        比较两个版本的预发布版本标签
     */
    private func isPreReleaseLesser(preRelease: String?) -> Bool {

        // a non-pre-release is not lesser
        guard let selfPreRelease = self.preRelease else {
            return false
        }

        // a pre-release version is lesser than a non-pre-release
        guard let otherPreRelease = preRelease else {
            return true
        }

        // same pre-release version has no precedence. Build metadata could differ,
        // but there is no ordering defined on build metadata
        guard selfPreRelease != otherPreRelease else {
            return false // undefined ordering
        }

        // Compare dot separated components one by one
        // From http://semver.org/:
        // "Precedence for two pre-release versions with the same major, minor, and patch
        // version MUST be determined by comparing each dot separated identifier from left
        // to right until a difference is found [...]. A larger set of pre-release fields
        // has a higher precedence than a smaller set, if all of the preceding
        // identifiers are equal."

        let selfComponents = selfPreRelease.components(separatedBy: ".")
        let otherComponents = otherPreRelease.components(separatedBy: ".")
        let nonEqualComponents = zip(selfComponents, otherComponents)
            .filter { $0.0 != $0.1 }

        for (selfComponent, otherComponent) in nonEqualComponents {
            return selfComponent.lesserThanPreReleaseVersionComponent(other: otherComponent)
        }

        // if I got here, the two pre-release are not the same, but there are not non-equal
        // components, so one must have move pre-components than the other
        return selfComponents.count < otherComponents.count
    }

    //返回版本是否具有相同的数值组件(主要、次要、补丁)
    func hasSameNumericComponents(version: SemanticVersion) -> Bool {
        return self.components == version.components
    }
    
}

extension String {

    /// Returns the Int value of the string, if the string is only composed of digits
    private var numericValue: Int? {
        if !self.isEmpty && self.rangeOfCharacter(from: SemanticVersion.semVerDecimalDigits.inverted) == nil {
            return Int(self)
        }
        return nil
    }

    /// Returns whether the string, considered a pre-release version component, should be
    /// considered lesser than another pre-release version component
    fileprivate func lesserThanPreReleaseVersionComponent(other: String) -> Bool {
        // From http://semver.org/:
        // "[the order is defined] as follows: identifiers consisting of only
        // digits are compared numerically and identifiers with letters or hyphens are
        // compared lexically in ASCII sort order. Numeric identifiers always have lower
        // precedence than non-numeric identifiers"

        guard let numericSelf = self.numericValue else {
            guard other.numericValue != nil else {
                // other is not numeric, self is not numeric, compare strings
                return self.compare(other) == .orderedAscending
            }
            // other is numeric, self is not numeric, other is lower
            return false
        }

        guard let numericOther = other.numericValue else {
            // other is not numeric, self is numeric, self is lower
            return true
        }

        return numericSelf < numericOther
    }
}

extension SemanticVersion: Scannable {
 
    /**
        尝试从字符串扫描器中解析人类可读的格式“a.b.c”的SemanticVersion版本
     */
    static func from(_ scanner: Scanner) -> Result<SemanticVersion, ScannableError> {

        
        
        //扫描“a.b.c”
        guard let version = scanner.scanCharacters(from: versionCharacterSet) else {
            return .failure(ScannableError(message: "expected version", currentLine: scanner.currentLine))
        }
        
//        var versionBuffer: NSString?
//        guard scanner.scanCharacters(from: versionCharacterSet, into: &versionBuffer),
//            let version = versionBuffer as String? else {
//            return .failure(ScannableError(message: "expected version", currentLine: scanner.currentLine))
//        }

        //划分主版本号、次版本号、补丁号，放入[Substring]数组中
        let components = version
            .split(omittingEmptySubsequences: false) { $0 == "." }
        guard !components.isEmpty else {
            return .failure(ScannableError(message: "expected version", currentLine: scanner.currentLine))
        }
        
        
        guard components.count <= 3 else {
            return .failure(ScannableError(message: "found more than 3 dot-separated components in version", currentLine: scanner.currentLine))
        }

        
        func parseVersion(at index: Int) -> Int? {
            return components.count > index ? Int(components[index]) : nil
        }

        guard let major = parseVersion(at: 0) else {
            return .failure(ScannableError(message: "expected major version number", currentLine: scanner.currentLine))
        }

        guard let minor = parseVersion(at: 1) else {
            return .failure(ScannableError(message: "expected minor version number", currentLine: scanner.currentLine))
        }

        let hasPatchComponent = components.count > 2
        let patch = parseVersion(at: 2)
        guard !hasPatchComponent || patch != nil else {
            return .failure(ScannableError(message: "invalid patch version", currentLine: scanner.currentLine))
        }

        /**
            扫描预发布版本标签
         */
        let preRelease = scanner.scanStringWithPrefix("-", until: "+")
        
        /**
            扫描构建号
         */
        let buildMetadata = scanner.scanStringWithPrefix("+", until: "")
        
        
        
        guard scanner.isAtEnd else {
            return .failure(ScannableError(message: "expected valid version", currentLine: scanner.currentLine))
        }

        /**
            如果预发布版本标签中包含无效字符，输出错误
         */
        if
            let preRelease = preRelease,
            let error = SemanticVersion.validatePreRelease(preRelease, fullVersion: version)
        {
            return .failure(error)
        }
        
        /**
            如果构建号中包含无效字符，输出错误
         */
        if
            let buildMetadata = buildMetadata,
            let error = SemanticVersion.validateBuildMetadata(buildMetadata, fullVersion: version)
        {
            return .failure(error)
        }


        guard (preRelease == nil && buildMetadata == nil) || hasPatchComponent else {
            return .failure(ScannableError(message: "can not have pre-release or build metadata without patch, in \"\(version)\""))
        }

        
        return .success(self.init(major, minor, patch ?? 0, preRelease: preRelease, buildMetadata: buildMetadata))
        
        
    }

    /// 如果构建号中包含无效字符，输出错误，否则输出nil
    static private func validateBuildMetadata(_ buildMetadata: String, fullVersion: String) -> ScannableError? {
        guard !buildMetadata.isEmpty else {
            return ScannableError(message: "Build metadata is empty after '+', in \"\(fullVersion)\"")
        }
        guard !buildMetadata.containsAny(invalidBuildMetadataCharacters) else {
            return ScannableError(message: "Build metadata contains invalid characters, in \"\(fullVersion)\"")
        }
        return nil
    }

    /// 如果预发布版本标签中包含无效字符，输出错误，否则输出nil
    static private func validatePreRelease(_ preRelease: String, fullVersion: String) -> ScannableError? {
        guard !preRelease.isEmpty else {
            return ScannableError(message: "Pre-release is empty after '-', in \"\(fullVersion)\"")
        }

        let components = preRelease.components(separatedBy: preReleaseComponentsSeparator)
        guard components.first(where: { $0.containsAny(invalidBuildMetadataCharacters) }) == nil else {
            return ScannableError(message: "Pre-release contains invalid characters, in \"\(fullVersion)\"")
        }

        guard components.first(where: { $0.isEmpty }) == nil else {
            return ScannableError(message: "Pre-release component is empty, in \"\(fullVersion)\"")
        }

        // swiftlint:disable:next first_where
        guard components
            .filter({ !$0.containsAny(SemanticVersion.semVerDecimalDigits.inverted) && $0 != "0" })
            // MUST NOT include leading zeros
            .first(where: { $0.hasPrefix("0") }) == nil else {
                return ScannableError(message: "Pre-release contains leading zero component, in \"\(fullVersion)\"")
        }
        return nil
    }
    
}

extension Scanner {

    /// Scans a string that is supposed to start with the given prefix, until the given
    /// string is encountered.
    /// - returns: the scanned string without the prefix. If the string does not start with the prefix,
    /// or the scanner is at the end, it returns `nil` without advancing the scanner.
    fileprivate func scanStringWithPrefix(_ prefix: Character, until: String) -> String? {
        guard !self.isAtEnd, self.remainingSubstring?.first == prefix else { return nil }

        guard let stringWithPrefix = self.scanUpToString(until), stringWithPrefix.first == prefix else {
            return nil
        }
        
//        var buffer: NSString?
//        self.scanUpTo(until, into: &buffer)
//        guard let stringWithPrefix = buffer as String?, stringWithPrefix.first == prefix else {
//            return nil
//        }
        
        return String(stringWithPrefix.dropFirst())
    }

    /// The string (as `Substring?`) that is left to scan.
    ///
    /// Accessing this variable will not advance the scanner location.
    ///
    /// - returns: `nil` in the unlikely event `self.scanLocation` splits an extended grapheme cluster.
    var remainingSubstring: Substring? {
        return Range(
            NSRange(
                location: self.scanLocation /* our UTF-16 offset */,
                length: (self.string as NSString).length - self.scanLocation
            ),
            in: self.string
        ).map {
            self.string[$0]
        }
    }
    
}


extension String {

    /// Returns true if self contain any of the characters from the given set
    fileprivate func containsAny(_ characterSet: CharacterSet) -> Bool {
        return self.rangeOfCharacter(from: characterSet) != nil
    }
}



extension SemanticVersion: CustomStringConvertible {
    var description: String {
        var description = components.map { String($0) } .joined(separator: ".")
        if let preRelease = self.preRelease {
            description += "-\(preRelease)"
        }
        if let buildMetadata = self.buildMetadata {
            description += "+\(buildMetadata)"
        }
        return description
    }
}
