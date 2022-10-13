//
//  ResolutionProject.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/4.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

final class ResolutionProject {
    
    /**
            返回一个依赖项的可用版本数组
     */
    private func versionsForDependency(for dependency: Dependency) -> Result<[PinnedVersion], ResolverError> {
        let dependencyVersions = MBPluginManager.shared.allPackages.filter{ dependency.name.lowercased() == $0.name.lowercased() }.map{ (package) -> PinnedVersion in
            return PinnedVersion(package.version)
        }
        
        if dependencyVersions.isEmpty {
            return .failure(.taggedVersionNotFound(dependency))
        }
        else{
            return .success(dependencyVersions)
        }
    }

    
    /**
            加载特定版本依赖项的所有依赖，返回[依赖: 版本范围]字典
     */
    private func dependenciesForDependency(for dependency: Dependency, version: PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError> {
        
        let packages = MBPluginManager.shared.dependencies(for: dependency.name);
        
        var result:[Dependency: VersionSpecifier] = [:]
        
        for package in packages {
            result[Dependency(package.name)] = .any
        }
        
        return .success(result)
    }
    
    /**
            加载特定版本依赖项的所有前置依赖，返回[依赖: 版本范围]字典
     */
    func forwardDependenciesForDependency(for dependency: Dependency, version: PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError> {
        
        let pinnedDependency = MBPluginManager.shared.allPackages.first{ dependency.name.lowercased() == $0.name.lowercased() && version == PinnedVersion($0.version) }
        
        if let pinnedDependency = pinnedDependency {
            var result:[Dependency: VersionSpecifier] = [:]

            for dependencyName in pinnedDependency.forwardDependencies.keys{
                result[Dependency(dependencyName)] = .any
            }
            
            return .success(result)
        }
        else{
            return .failure(.internalError(description: "no forwardDependencies"))
        }
    }
    
    
    
    /**
            解析对依赖某个版本的Git引用，返回可用版本数组
     */
    private func resolvedGitReference(_ dependency: Dependency, reference: String) -> Result<[PinnedVersion], ResolverError> {
            return .failure(.internalError(description: "no resolvedGitReference"))
    }
    
    
    
}
