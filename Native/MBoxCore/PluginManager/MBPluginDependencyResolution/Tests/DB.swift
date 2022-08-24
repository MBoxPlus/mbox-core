
//
//  DB.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

let git1 = Dependency("git1")
let git2 = Dependency("git2")
let git3 = Dependency("git3")
let github1 = Dependency( "github1")
let github2 = Dependency( "github2")
let github3 = Dependency( "github3")
let github4 = Dependency( "github4")
let github5 = Dependency( "github5")
let github6 = Dependency( "github6")


extension PinnedVersion {
    static let v0_1_0 = PinnedVersion("v0.1.0")
    static let v1_0_0 = PinnedVersion("v1.0.0")
    static let v1_1_0 = PinnedVersion("v1.1.0")
    static let v1_2_0 = PinnedVersion("v1.2.0")
    static let v2_0_0 = PinnedVersion("v2.0.0")
    static let v2_0_0_beta_1 = PinnedVersion("v2.0.0-beta.1")
    static let v2_0_1 = PinnedVersion("v2.0.1")
    static let v3_0_0_beta_1 = PinnedVersion("v3.0.0-beta.1")
    static let v3_0_0 = PinnedVersion("v3.0.0")
}

extension SemanticVersion {
    static let v0_1_0 = SemanticVersion(0, 1, 0)
    static let v1_0_0 = SemanticVersion(1, 0, 0)
    static let v1_1_0 = SemanticVersion(1, 1, 0)
    static let v1_2_0 = SemanticVersion(1, 2, 0)
    static let v2_0_0 = SemanticVersion(2, 0, 0)
    static let v2_0_1 = SemanticVersion(2, 0, 1)
    static let v3_0_0 = SemanticVersion(3, 0, 0)
}



//protocol ResolverProtocol {
//    /**
//        versionsForDependency - 返回一个依赖项的可用版本数组
//        dependenciesForDependency - 加载特定版本依赖项的所有依赖，返回[依赖: 版本范围]字典
//        resolvedGitReference - 解析对依赖某个版本的Git引用，返回可用版本数组
//     */
//    init(
//        versionsForDependency: @escaping (Dependency) -> Result<[PinnedVersion], ResolverError>,
//        dependenciesForDependency: @escaping (Dependency, PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError>,
//        resolvedGitReference: @escaping (Dependency, String) -> Result<[PinnedVersion], ResolverError>
//    )
//
//    /**
//    解析传入的[依赖: 版本范围]字典，得到每个依赖项及其所有嵌套依赖项的[依赖:版本固定值]字典并返回
//     输入：
//         dependencies - 字典，其中字典的键是Dependency类型，作为依赖的唯一标识使用；值是VersionSpecifier类型，描述依赖的版本规范。
//                dependencies代表需要解析的[依赖: 版本范围]字典
//         lastResolved - 字典，其中字典的键是Dependency类型，代表依赖；值是PinnedVersion类型，代表一个项目可以固定到的不可变版本。
//                lastResolved代表已经存在的[依赖: 版本固定值]
//
//                                //TODO lastResolved的意义
//
//         dependenciesToUpdate - String类型数组可选值，代表需要更新的依赖列表。
//     */
//    func resolve(
//        dependencies: [Dependency: VersionSpecifier],
//        lastResolved: [Dependency: PinnedVersion]?,
//        dependenciesToUpdate: [String]?
//    ) -> Result<[Dependency: PinnedVersion], ResolverError>
//}



struct DB {
    var versions: [Dependency: [PinnedVersion: [Dependency: VersionSpecifier]]]
    var forwarddependencies: [Dependency: [PinnedVersion: [Dependency: VersionSpecifier]]]
    var references: [Dependency: [String: PinnedVersion]] = [:]
    
    func versionsForDependency(for dependency: Dependency) -> Result<[PinnedVersion], ResolverError> {
        if let versions = self.versions[dependency] {
            return .success([PinnedVersion](versions.keys))
        } else {
            return .failure(.taggedVersionNotFound(dependency))
        }
    }

    
    func dependenciesForDependency(for dependency: Dependency, version: PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError> {
        //print("dependenciesForDependency \(dependency)  \(version)")
        if let dependencies = self.versions[dependency]?[version] {
            return .success(dependencies)
        } else  {
            return .success([:])
            //return .failure(.internalError(description: "no dependenciesForDependency"))
        }
    }
    
    func forwardDependenciesForDependency(for dependency: Dependency, version: PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError> {
        
        if let dependencies = self.forwarddependencies[dependency]?[version] {
            return .success(dependencies)
        } else  {
            return .success([:])
            //return .failure(.internalError(description: "no dependenciesForDependency"))
        }
    }
    
    
    
    func resolvedGitReference(_ dependency: Dependency, reference: String) -> Result<[PinnedVersion], ResolverError> {
        //print("resolvedGitReference \(dependency)  \(reference)")
        if let version = references[dependency]?[reference] {
            return .success([version])
        } else {
            return .failure(.internalError(description: "no resolvedGitReference"))
        }
    }
    
    func resolver(_ resolverType: ResolverProtocol.Type = Resolver.self) -> ResolverProtocol {
        return resolverType.init(
            versionsForDependency: self.versionsForDependency(for:),
            dependenciesForDependency: self.dependenciesForDependency(for:version:),
            forwardDependenciesForDependency:self.forwardDependenciesForDependency(for:version:),
            resolvedGitReference: self.resolvedGitReference(_:reference:)
        )
    }
    
    func resolve(
        _ resolverType: ResolverProtocol.Type,
        _ dependencies: [Dependency: VersionSpecifier],
        resolved: [Dependency: PinnedVersion] = [:],
        updating: Set<Dependency> = []
        ) -> Result<[Dependency: PinnedVersion], ResolverError> {
        let resolver = resolverType.init(
            versionsForDependency: self.versionsForDependency(for:),
            dependenciesForDependency: self.dependenciesForDependency(for:version:),
            forwardDependenciesForDependency:self.forwardDependenciesForDependency(for:version:),
            resolvedGitReference: self.resolvedGitReference(_:reference:)
        )
        return resolver
            .resolve(
                dependencies: dependencies,
                lastResolved: resolved,
                dependenciesToUpdate: updating.map { $0.name }
        )
        
    }

    

    
}

extension DB: ExpressibleByDictionaryLiteral {
    init(dictionaryLiteral elements: (Dependency, [PinnedVersion: [Dependency: VersionSpecifier]])...) {
        self.init(versions: [:], forwarddependencies: [:], references: [:])
        for (key, value) in elements {
            versions[key] = value
        }
    }
}


