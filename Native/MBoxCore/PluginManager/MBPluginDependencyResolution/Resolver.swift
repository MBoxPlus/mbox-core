//
//  Resolver.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation


/// 解析非循环依赖图的协议
protocol ResolverProtocol {
    /**
        versionsForDependency - 返回一个依赖项的可用版本数组
        dependenciesForDependency - 加载特定版本依赖项的所有依赖，返回[依赖: 版本范围]字典
        forwardDependenciesForDependency - 加载特定版本依赖项的前置依赖，返回[依赖: 版本范围]字典
        resolvedGitReference - 解析对依赖某个版本的Git引用，返回可用版本数组
     
        allPackages
     
     A0.0.1 B >=1 C~>2
      从lazy var allPackages: [MBPluginPackage] = all() 中取数据
     
     */
    init(
        versionsForDependency: @escaping (Dependency) -> Result<[PinnedVersion], ResolverError>,
        dependenciesForDependency: @escaping (Dependency, PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError>,
        forwardDependenciesForDependency: @escaping (Dependency, PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError>,
        resolvedGitReference: @escaping (Dependency, String) -> Result<[PinnedVersion], ResolverError>
    )

    /**
    解析传入的[依赖: 版本范围]字典，得到每个依赖项及其所有嵌套依赖项的[依赖:版本固定值]字典并返回
     输入：
         dependencies - 字典，其中字典的键是Dependency类型，作为依赖的唯一标识使用；值是VersionSpecifier类型，描述依赖的版本规范。
                dependencies代表需要解析的[依赖: 版本范围]字典
         lastResolved - 字典，其中字典的键是Dependency类型，代表依赖；值是PinnedVersion类型，代表一个项目可以固定到的不可变版本。
                lastResolved是已经存在的[依赖: 版本固定值]字典，代表上一次解析结果
         dependenciesToUpdate - String类型数组可选值，代表需要更新的依赖白名单。
                 当解析出依赖树之后，如果存在白名单和上一次解析结果
                            对于不在白名单或其依赖项中的每个依赖树节点
                                如果它在'lastResolved'中有一个版本，它必须匹配，否则返回一个unsatisfiableDependencyList错误
                                如果节点没有以前的版本，它将从返回的图中删除，但图仍然被认为有效
     
     使用：
                1. 第一次解析依赖，不存在上一次解析结果：
                  输入：dependencies  ->  [依赖: 版本范围]字典
                       lastResolved -> nil
                       dependenciesToUpdate   ->  nil
                
                2. 存在上一次解析结果lastResolved，待更新的依赖放到dependenciesToUpdate中，[依赖: 版本范围]字典放到dependencies中
                 输入：    dependencies  ->  [依赖: 版本范围]字典
                        lastResolved ->    [依赖: 版本固定值]字典，代表上一次解析结果
                        dependenciesToUpdate   -> 相比lastResolved中的依赖，dependencies中多出来的依赖项，
                                            表示这些依赖及它们的子依赖需要更新，其他沿用lastResolved的版本
     */
    func resolve(
        dependencies: [Dependency: VersionSpecifier],
        lastResolved: [Dependency: PinnedVersion]?,
        dependenciesToUpdate: [String]?
    ) -> Result<[Dependency: PinnedVersion], ResolverError>
}

/**
    解析非循环依赖图
 */
struct Resolver: ResolverProtocol {
    
    private let versionsForDependency:  (Dependency) -> Result<[PinnedVersion], ResolverError>
    private let dependenciesForDependency:  (Dependency, PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError>
    private let forwardDependenciesForDependency: (Dependency, PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError>
    private let resolvedGitReference: (Dependency, String) -> Result<[PinnedVersion], ResolverError>

    /**
        versionsForDependency - 返回一个依赖项的可用版本数组
        dependenciesForDependency - 加载特定版本依赖项的所有依赖，返回[依赖: 版本范围]字典
        forwardDependenciesForDependency - 加载特定版本依赖项的前置依赖，返回[依赖: 版本范围]字典
        resolvedGitReference - 解析对依赖某个版本的Git引用，返回可用版本数组
     */
    init(
        versionsForDependency: @escaping (Dependency) -> Result<[PinnedVersion], ResolverError>,
        dependenciesForDependency: @escaping (Dependency, PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError>,
        forwardDependenciesForDependency: @escaping (Dependency, PinnedVersion) -> Result<[Dependency: VersionSpecifier], ResolverError>,
        resolvedGitReference: @escaping (Dependency, String) -> Result<[PinnedVersion], ResolverError>
    ){
        self.versionsForDependency = versionsForDependency
        self.dependenciesForDependency = dependenciesForDependency
        self.forwardDependenciesForDependency = forwardDependenciesForDependency
        self.resolvedGitReference = resolvedGitReference
    }
    
    
    /**
    解析传入的[依赖: 版本范围]字典，得到每个依赖项及其所有嵌套依赖项的[依赖:版本固定值]字典并返回
     输入：
         dependencies - 字典，其中字典的键是Dependency类型，作为依赖的唯一标识使用；值是VersionSpecifier类型，描述依赖的版本规范。
                dependencies代表需要解析的[依赖: 版本范围]字典
         lastResolved - 字典，其中字典的键是Dependency类型，代表依赖；值是PinnedVersion类型，代表一个项目可以固定到的不可变版本。
                lastResolved代表已经存在的[依赖: 版本固定值]
         dependenciesToUpdate - String类型数组可选值，代表需要更新的依赖列表。
     */
    func resolve(
        dependencies: [Dependency: VersionSpecifier],
        lastResolved: [Dependency: PinnedVersion]? = nil,
        dependenciesToUpdate: [String]? = nil
    ) -> Result<[Dependency: PinnedVersion], ResolverError>{
        
        //1.根据lastResolved和dependenciesToUpdate创建一张空的依赖图
        let baseGraph = DependencyGraph(whitelist: dependenciesToUpdate, lastResolved: lastResolved, dependencies: dependencies)
        
        /*2.
            传入[依赖: 版本范围]字典和空依赖图，递归地将依赖插入图中，返回包含每个依赖项及其所有嵌套依赖项的有效图；
            根据有效图中所有依赖得到[依赖:版本固定值]字典并返回
         */
        return process(dependencies: dependencies, in: baseGraph)
            .map { graph in graph.versions }

    }
    
    // 用于此解析器实例的错误缓存
    private let errorCache = ErrorCache()

    /**
        传入[依赖: 版本范围]字典、依赖图以及字典中依赖的父节点，递归地将依赖插入图中，返回包含每个依赖项及其所有嵌套依赖项的有效图
        
     */
    private func process(
        dependencies: [Dependency: VersionSpecifier],
        in baseGraph: DependencyGraph,
        withParent parent: DependencyNode? = nil
        ) -> Result<DependencyGraph, ResolverError> {
        /*1.
            由[依赖:版本范围]字典、依赖图baseGraph、字典的父节点、以及此解析器实例的错误缓存得到一个NodePermutations类型的值，
            NodePermutations类型的值是一个自定义迭代器，用于按照顺序返回一张有效的依赖图
         */
        let permutationsOfNodes = self.nodePermutations(for: dependencies, in: baseGraph, withParent: parent)
        
        /*2.
            根据有效依赖排序序列返回一张有效的依赖图
                 a. 新图中包含依赖图baseGraph中节点以及[依赖:版本范围]字典中节点
                 b. 对于[依赖:版本范围]字典中所有节点的子依赖，如果不在新图中，把它们加入新图的未访问节点列表
        */
        return permutationsOfNodes.flatMap { permutations in
                // 只有在任何排列都没有产生有效的图时才抛出错误
                var errResult: Result<DependencyGraph, ResolverError>?
                for nextGraphResult in permutations {
                    // 如果创建依赖图失败，则立即返回失败
                    guard case let .success(nextGraph) = nextGraphResult else { return errResult! }

                    /**
                        递归地生成包含更多节点的依赖图，
                            直到所有节点都被访问过，返回最终依赖图
                            如果出错，保留出错的errorCache，返回
                     */
                    let nextResult = self.process(graph: nextGraph)
                    switch nextResult {
                    case .success:
                        return nextResult
                    case .failure:
                        errResult = errResult ?? nextResult
                    }
                }
                return errResult!
            }
    }
    
    
    /*
     由[依赖:版本范围]字典、依赖图baseGraph、字典的父节点、以及此解析器实例的错误缓存得到一个NodePermutations类型的值，
     NodePermutations类型的值是一个自定义迭代器，用于按照顺序返回一张有效的依赖图，
             a. 新图中包含依赖图baseGraph中节点以及[依赖:版本范围]字典中节点
             b. 对于[依赖:版本范围]字典中所有节点的子依赖，如果不在新图中，把它们加入新图的未访问节点列表
    */
    private func nodePermutations(
        for dependencies: [Dependency: VersionSpecifier],
        in baseGraph: DependencyGraph,
        withParent parentNode: DependencyNode?
        ) -> Result<NodePermutations, ResolverError> {
        
        let producer = Result<[Dependency: VersionSpecifier], ResolverError>.success(dependencies)
        
        let DependencyNodeTwoDimensionalArray = producer.flatMap { dependenciesDictionary -> Result<[[DependencyNode]], ResolverError> in
                var NodeTwoDimesionArray:[[DependencyNode]] = []
                for (dependency, specifier) in dependenciesDictionary {
                    /**
                    查询依赖dependency的固定版本号，放入versionProducer中
                        ｜如果版本范围中包含git地址，由git地址得到固定版本号
                        ｜如果依赖已经存在图中，返回图中节点的固定版本号
                        ｜否则使用versionsForDependency方法查询依赖的所有版本，过滤出满足版本范围的固定版本，放入versionProducer中
                     */
                    let versionProducer: Result<[PinnedVersion], ResolverError>
                    
                    if case let .gitReference(refName) = specifier {
                        versionProducer = self.resolvedGitReference(dependency, refName)
                    } else if let existingNode = baseGraph.node(for: dependency) {
                        //我们仍然适当地考虑图边，“排列”所有的依赖关系，但如果它已经被固定，唯一可能的值是那个固定版本
                        versionProducer = .success([existingNode.proposedVersion])
                    } else {
                        versionProducer = self.versionsForDependency(dependency).map{
                            versions -> [PinnedVersion] in
                                return versions.filter{specifier.isSatisfied(by: $0) }
                        }
                    }
                    /**
                        根据依赖dependency满足条件的固定版本号数组，
                        得到每个依赖的DependencyNode数组，数组中每个值对应一个可用的版本号
                    */
                    let DependencyNodeProducer = versionProducer.map{ versions -> [DependencyNode] in
                        let DependencyNodeArray = versions.map { pinnedVersion -> DependencyNode in
                            
                            let forwarddependencies = self.forwardDependenciesForDependency(dependency, pinnedVersion).value
                        
                            return DependencyNode(dependency: dependency, proposedVersion: pinnedVersion, versionSpecifier: specifier, parent: parentNode, forwardDependencies: forwarddependencies)
                        }
                        return DependencyNodeArray
                    }
    
                    /**
                        对于每一个DependencyNode数组，如果数组不空，将排序后的DependencyNode数组加入二维数组中，继续执行；
                         如果存在数组为空，返回错误停止执行
                    */
                    switch DependencyNodeProducer {
                    case let .success(nodes):
                        guard !nodes.isEmpty else {
                           return .failure(ResolverError.requiredVersionNotFound(dependency, specifier))
                        }
                        /**
                         优化：将DependencyNode数组排序，
                         如果lastResolved中依赖dependency存在固定版本，且dependency不在白名单中
                         包含在lastResolved中的版本放在数组最前方，
                         剩余节点按照版本从高到低排列
                         */

                        var sortedNodes = nodes.sorted()
                        if let whitelist = baseGraph.whitelist, !whitelist.contains(dependency.name), let lastResolved = baseGraph.lastResolved, let pinnedVersion = lastResolved[dependency] {
                            let newNode = sortedNodes.removeFirst{ $0.proposedVersion == pinnedVersion }
                            if let node = newNode {
                                sortedNodes.insert(node, at: 0)
                            }
                        }
                        NodeTwoDimesionArray.append(nodes.sorted())
                    case .failure:
                        return .failure(ResolverError.requiredVersionNotFound(dependency, specifier))
                    }
                    
                }
            
            return .success(NodeTwoDimesionArray)
        }
        
        /*
            DependencyNodeTwoDimensionalArray中包含一个二维数组，数组中的每一项都是排序后的DependencyNode数组，
            由依赖版本二维数组、当前的图、errorCache得到一个NodePermutations
         */
        return DependencyNodeTwoDimensionalArray.map { nodesToPermute -> NodePermutations in
                return NodePermutations(
                    baseGraph: baseGraph,
                    nodesToPermute: nodesToPermute,
                    errorCache: self.errorCache)
       }
    }
    
    
    /**
        递归地生成有效的依赖图
            输入为一张图，其中包含图中节点点集、图中节点边集、未访问节点列表
            递归地处理图中下一个未访问的节点。
    */
    private func process(graph: DependencyGraph) -> Result<DependencyGraph, ResolverError> {
        /** 1.
            得到图中下一个未被访问的节点
            如果所有节点都被访问过了，那么返回最后生成的图
        */
        var graph = graph
        guard let node = graph.nextNodeToVisit() else {
            return graph.validateFinalGraph()
        }
        
        /** 2.
            根据未访问节点的名字和固定版本返回节点的[依赖: 版本范围]字典
        */
        let dependencies = self.dependenciesForDependency(node.dependency, node.proposedVersion)
        
        /** 3.
            对节点（依赖，版本规范）数组中的每个依赖，检查依赖范围是否与图冲突
                如果不存在冲突，继续执行
                如果存在冲突，在errorCache中保存失败记录，返回error停止向下执行
        */
        
        let DictoryForDependencyVersionSpecifier = dependencies.flatMap{ DependencyDictory -> Result<[Dependency: VersionSpecifier], ResolverError> in
            for (child, newSpecifier) in DependencyDictory {
                /*3.1
                    如果依赖不在图中，继续比较下一个
                 */
                guard let existingChildNode = graph.node(for: child) else {
                        break
                }
                
                /*3.2
                    当依赖在图中时：
                        ｜
                        ｜如果图中固定的依赖版本满足新添加的依赖范围，继续比较下一个
                        ｜
                        ｜如果图中固定的依赖版本不满足新添加的依赖范围，先执行以下操作，返回失败
                            ｜判断新的依赖范围和原本的范围是否存在交集
                                ｜如果不存在交集，
                                    |如果图中已存在依赖存在父依赖，在errorCache中保存失败的（节点：（版本：（父依赖：版本）））四元组
                                    ｜如果新添加的依赖不存在父依赖，在errorCache中保存（依赖：版本）二元组
                */
                guard newSpecifier.isSatisfied(by: existingChildNode.proposedVersion) else {
                    if intersection(newSpecifier, existingChildNode.versionSpecifier) == nil {
                        if let existingParent = existingChildNode.parent {
                            self.errorCache.addIncompatibilityBetween((node.dependency, node.proposedVersion), (existingParent.dependency, existingParent.proposedVersion))
                        } else {
                            self.errorCache.addRootIncompatibility(for: (node.dependency, node.proposedVersion))
                        }
                    }
                    
                    let existingRequirement: ResolverError.VersionRequirement = (specifier: existingChildNode.versionSpecifier, fromDependency: existingChildNode.parent?.dependency)
                    let newRequirement: ResolverError.VersionRequirement = (specifier: newSpecifier, fromDependency: node.dependency)
                    return .failure(.incompatibleRequirements(child, existingRequirement, newRequirement))
                }
            }
            
            return .success(DependencyDictory)
            
        }
        
        /**4.
            重排依赖，将每个排列附加到`graph`，作为指定节点的依赖项(或者作为根)。然后递归地处理每张图
        */
        return DictoryForDependencyVersionSpecifier.flatMap{
            (dependencies: [Dependency: VersionSpecifier]) -> Result<DependencyGraph, ResolverError> in
            return self.process(dependencies: dependencies, in: graph, withParent: node)
        }
        
    }
    
    
    
}




/**
    NodePermutations是一个自定义迭代器，用于产生排列。
    与“ErrorCache”一起使用，使我们能够在产生排列之前进行短路，而不是在结果出现时进行过滤。
    由依赖版本二维数组、当前的图、errorCache得到一个NodePermutations。
*/
private struct NodePermutations: Sequence, IteratorProtocol {
    private let baseGraph: DependencyGraph
    private var currentNodeValues: [Dimension]
    private let errorCache: ErrorCache
    private var hasNext = true
 
    /*
        实例化'nodesToPermute'的排列序列。
        每个排列通过将节点添加到图中的方式从`baseGraph`创建一个新图。
    */
    init(
        baseGraph: DependencyGraph,
        nodesToPermute: [[DependencyNode]],
        errorCache: ErrorCache
    ) {
        self.baseGraph = baseGraph
        self.currentNodeValues = nodesToPermute.map { Dimension($0) }
        self.errorCache = errorCache
    }
    
    /*
        生成下一个排列，跳过任何被errorCache认为无效的组合
    */
    mutating func next() -> Result<DependencyGraph, ResolverError>? {
        guard hasNext else { return nil }
        
        //1. 如果在递归中出现更高级别的不兼容性，请跳过整个序列
        guard errorCache.graphIsValid(baseGraph) else { return nil }

        //2. 生成下一张有效的图
        guard let graph = nextValidGraph() else { return nil }

        //3. 递增排列顺序
        incrementIndexes()
        return graph
    }
    
    
    /*
        生成下一张有效的图，跳过无效排列
        如果图生成结果出错时返回error
     */
    private mutating func nextValidGraph() -> Result<DependencyGraph, ResolverError>? {
        var result: Result<DependencyGraph, ResolverError>?
        
        // 跳过无效排列
        while hasNext && result == nil {
            result = generateGraph()
            /**
                                    
             */
            guard case let .success(generatedGraph) = generateGraph() else { break }

            
            let versions = generatedGraph.versions
            // swiftlint:disable:next identifier_name
            /**
             判断新生成的图中是否存在冲突
                                对于所有的依赖当前版本节点
                                    如果节点与图中节点冲突，先改变依赖版本，再重新生成图
             */
            for i in (currentNodeValues.startIndex..<currentNodeValues.endIndex).reversed() {
                let node = currentNodeValues[i].node
                if !errorCache.dependencyIsValid(node.dependency, given: versions) {
                    incrementIndexes(startingAt: currentNodeValues.index(after: i))
                    result = nil
                    break
                }
            }
        }

        return result
    }
    
    
    /**
                判断[依赖 :固定版本]字典versions是否满足节点node的前置条件
     */
    private func isSatisfiedPrecondition(_ node:DependencyNode, _ versions:[Dependency: PinnedVersion]) -> Bool {
        for (dependency, version) in node.forwardDependencies {
            guard let pinnedversion = versions[dependency], version.isSatisfied(by: pinnedversion) else{
                return false
            }
        }
        
        return true
    }
    
    //从存储在currentNodeValues数组中的索引创建一个新图
    private func generateGraph() -> Result<DependencyGraph, ResolverError> {
        /**1
             得到一组节点数组，包含当前所有依赖的一个固定版本

         */
        let newNodes = currentNodeValues.map { $0.node }
        
        /**2
            检查每个节点的前置依赖是否满足，把不满足的放在集合nodesUnsatisfiedPrecondition中
            versions中存放图中[依赖 :固定版本]字典   versions: [Dependency: PinnedVersion]
         */
        var nodesUnsatisfiedPrecondition = baseGraph.unsatisfiedPrecondition
        var versions = baseGraph.versions
        
        for node in newNodes {
            if !isSatisfiedPrecondition(node, versions) {
                nodesUnsatisfiedPrecondition.insert(node)
            }
        }
        
        /**3
             得到满足前置依赖的节点数组
         */
        var satisfiedNodes = newNodes.filter { !nodesUnsatisfiedPrecondition.contains($0) }
        
        
        /**4
            把以上数组加到versions中
         */
        for node in satisfiedNodes {
            versions[node.dependency] = node.proposedVersion
        }
        
        var flag: Bool = true
        while flag {
            
            flag = false
            
            for node in nodesUnsatisfiedPrecondition {
                if isSatisfiedPrecondition(node, versions){
                    flag = true
                    versions[node.dependency] = node.proposedVersion
                    satisfiedNodes.append(node)
                }
            }
            
            for node in satisfiedNodes{
                nodesUnsatisfiedPrecondition.remove(node)
            }
        }

        /**2
            把所有依赖固定版本添加到图中
         */
        let newGraph = baseGraph.addNodes(satisfiedNodes)
        switch newGraph{
        case var .success(graph) :
            graph.unsatisfiedPrecondition = nodesUnsatisfiedPrecondition
            return .success(graph)
        case let .failure(error):
            return .failure(error)
        }
    }
    
    
    /**
        增加基本排列
            采用类似数字递增的方式，把每个依赖看作一位数值，若千位上依赖失败，重新置位个位和十位上的依赖，千位上依赖加一，其他位不变
     */
    private mutating func incrementIndexes(startingAt startingIndex: Array<Dimension>.Index? = nil) {
        guard hasNext else { return }

        // 'skip' any permutations as defined by 'startingIndex' by setting all subsequent values to their max. We don't count this as an 'incremented' occurrence.
        /**
                        如果第i个依赖上出现冲突
                            从第i+1到最后一个依赖都跳到最后一个版本
         */
        if let startingIndex = startingIndex {
            // swiftlint:disable:next identifier_name
            for i in (startingIndex..<currentNodeValues.endIndex) {
                currentNodeValues[i].skipRemaining()
            }
        }

        // If we 'reset' for every dimension, we've hit the end
        hasNext = false
        // swiftlint:disable:next identifier_name
        for i in (currentNodeValues.startIndex..<currentNodeValues.endIndex).reversed() {
            if currentNodeValues[i].increment() == .incremented {
                hasNext = true
                break
            }
        }
    }
    
}


/// Helper struct to track a single axis of a permutation
extension NodePermutations {
    enum IncrementResult {
        case incremented
        case reset
    }

    struct Dimension {
        let nodes: [DependencyNode]
        var index: Array<DependencyNode>.Index

        init(_ nodes: [DependencyNode]) {
            self.nodes = nodes
            self.index = nodes.startIndex
        }

        var node: DependencyNode {
            return nodes[index]
        }

        mutating func skipRemaining() {
            index = nodes.index(before: nodes.endIndex)
        }

        mutating func increment() -> IncrementResult {
            index = nodes.index(after: index)
            if index < nodes.endIndex {
                return .incremented
            } else {
                index = nodes.startIndex
                return .reset
            }
        }
    }
}



//当发现版本不兼容时跟踪引用类型，以便跳过后面的排列
private final class ErrorCache {
    typealias DependencyVersion = (dependency: Dependency, version: PinnedVersion)
    /*
        如果不存在交集，在incompatibilities中保存失败的（节点：（版本：（父依赖：父版本）））和（父节点：（父版本：（依赖：版本）））四元组
        如果新添加的依赖不存在父依赖，在rootIncompatibilites中保存（依赖：版本）二元组
    */
    private var incompatibilities: [Dependency: [PinnedVersion: [Dependency: Set<PinnedVersion>]]] = [:]
    private var rootIncompatibilites: [Dependency: Set<PinnedVersion>] = [:]
    
    
    /**
        判断给定图中所有依赖是否兼容
     */
    func graphIsValid(_ graph: DependencyGraph) -> Bool {
        let versions = graph.versions
        return !graph.allNodes.contains { !dependencyIsValid($0.dependency, given: versions) }
    }
    
    /**
        判断给定依赖是否兼容
     */
    func dependencyIsValid(_ dependency: Dependency, given versions: [Dependency: PinnedVersion]) -> Bool {
        guard let currentVersion = versions[dependency] else {
            return true
        }

        if rootIncompatibilites[dependency]?.contains(currentVersion) ?? false {
            return false
        }

        if let incompatibleDependencies = incompatibilities[dependency]?[currentVersion] {
            return !versions.contains { otherDependency, otherVersion in
                return incompatibleDependencies[otherDependency]?.contains(otherVersion) ?? false
            }
        }

        return true
    }
    
    /**
        添加与根版本范围的冲突
     */
    func addRootIncompatibility(for depVersion: DependencyVersion) {
        var versions = rootIncompatibilites.removeValue(forKey: depVersion.dependency) ?? Set()
        versions.insert(depVersion.version)
        rootIncompatibilites[depVersion.dependency] = versions
    }
    
    /**
        添加两个依赖版本范围的冲突
     */
    func addIncompatibilityBetween(_ dependencyVersion1: DependencyVersion, _ dependencyVersion2: DependencyVersion) {
        addIncompatibility(for: dependencyVersion1, to: dependencyVersion2)
        addIncompatibility(for: dependencyVersion2, to: dependencyVersion1)
    }
    
    /**
        添加冲突
     */
    private func addIncompatibility(for depVersion1: DependencyVersion, to depVersion2: DependencyVersion) {
        // Dive down into the proper set for lookup
        var versionMap = incompatibilities.removeValue(forKey: depVersion1.dependency) ?? [:]
        var versionIncompatibilities = versionMap.removeValue(forKey: depVersion1.version) ?? [:]
        var versions = versionIncompatibilities.removeValue(forKey: depVersion2.dependency) ?? Set()

        versions.insert(depVersion2.version)

        // Assign all values back into the maps
        versionIncompatibilities[depVersion2.dependency] = versions
        versionMap[depVersion1.version] = versionIncompatibilities
        incompatibilities[depVersion1.dependency] = versionMap
    }
    
}


/**
    表示一个非循环依赖图，其中每个依赖最多出现一次。
    依赖图可能存在于不完整或不一致的状态，表示正在进行的搜索。
 */
private struct DependencyGraph {
    
    //图中包含的所有节点的完整列表。
    var allNodes: Set<DependencyNode> = []

    //具有依赖关系的所有节点，与依赖关系列表本身(包括中间节点)相关联。
    var edges: [DependencyNode: Set<DependencyNode>] = [:]
    
    //仍然需要处理的节点列表(按应该处理的顺序)
    var unvisitedNodes: [DependencyNode] = []
    
    //不满足前置依赖条件的节点列表
    var unsatisfiedPrecondition: Set<DependencyNode> = []
    
    /**
        白名单中的依赖可以选择任意版本。
        lastResolved代表确定了版本的依赖
        一旦找到一个有效的图，首先过滤掉白名单中依赖，然后图中剩余依赖将给出在'lastResolved'中找到的值。
        如果它现在由于白名单而无效，则继续搜索
    */
    let originalDependencies:[Dependency : VersionSpecifier]?
    let whitelist: [String]?
    let lastResolved: [Dependency: PinnedVersion]?

    init(whitelist: [String]?, lastResolved: [Dependency: PinnedVersion]? = nil, dependencies:[Dependency : VersionSpecifier]? = nil) {
        self.whitelist = whitelist
        self.lastResolved = lastResolved
        self.originalDependencies = dependencies
    }
    
    //返回字典，字典的键是图中包含的所有节点依赖，值是节点依赖对应的固定版本
    var versions: [Dependency: PinnedVersion] {
        var versionDictionary: [Dependency: PinnedVersion] = [:]
        for node in allNodes {
            versionDictionary[node.dependency] = node.proposedVersion
        }
        return versionDictionary
    }
    
    //如果给定依赖在图中，返回给定依赖项的当前节点
    func node(for dependency: Dependency) -> DependencyNode? {
        return allNodes.first { $0.dependency == dependency }
    }


    /**
        将给定多个依赖节点添加到图中
    x
        按照给定的顺序将节点添加到未访问节点列表中
        成功时返回图本身
    */
    func addNodes<C: Collection>(_ nodes: C) -> Result<DependencyGraph, ResolverError>
        where C.Iterator.Element == DependencyNode {
            
            return nodes.reduce(.success(self)) { graph, node in
  
                //依次把数组中的节点添加到图中
                return graph.flatMap { $0.addNode(node) }
            }
    }
    
    /**
        将给定节点添加到图中
        将节点添加到未访问节点列表中
     */
    func addNode(_ node: DependencyNode) -> Result<DependencyGraph, ResolverError> {
        if allNodes.contains(node) {
            // 给定节点已经存在时，只更新边表
            return self.updateEdges(with: node)
        }

        var newGraph = self
        newGraph.allNodes.insert(node)
            
        //将节点添加到未访问节点列表中
        newGraph.unvisitedNodes.append(node)

        return newGraph.updateEdges(with: node)
    }
    
    /**
        生成一个新图，其中包含更新给定节点的边表
     */
    private func updateEdges(with node: DependencyNode) -> Result<DependencyGraph, ResolverError> {
        /**
            当给定节点不包含父节点时不存在新边，直接返回
         */
        guard let parent = node.parent else {
            return .success(self)
        }

        
        var newGraph = self
        var nodeSet = edges[parent] ?? Set()
        nodeSet.insert(node)

        // 如果给定节点已经具有依赖项，则将它们添加到列表中。
        if let dependenciesOfNode = edges[node] {
            nodeSet.formUnion(dependenciesOfNode)
        }

        newGraph.edges[parent] = nodeSet

        // 将嵌套依赖项添加到其祖先的列表中
        for (ancestor, var itsDependencies) in edges {
            if itsDependencies.contains(parent) {
                itsDependencies.formUnion(nodeSet)
                newGraph.edges[ancestor] = itsDependencies
            }
        }

        return .success(newGraph)
    }
    
    
    //得到图中下一个未被访问的节点
    mutating func nextNodeToVisit() -> DependencyNode? {
        return !unvisitedNodes.isEmpty ? unvisitedNodes.removeFirst() : nil
    }

    
    /**
     对完整图上的白名单运行最终验证(例如，不再有未访问的节点)
     对于不在白名单或其依赖项中的每个节点
        如果它在'lastResolved'中有一个版本，它必须匹配，否则返回一个unsatisfiableDependencyList错误
        如果节点没有以前的版本，它将从返回的图中删除，但图仍然被认为有效
     */
    func validateFinalGraph() -> Result<DependencyGraph, ResolverError> {
        
        /**
            1. 如果存在未访问的节点，返回失败
         */
        guard unvisitedNodes.isEmpty else {
            return .failure(.internalError(description: "Validating graph before it's been completely expanded"))
        }

        UI.logLoad("unsatisfiedPrecondition: \(unsatisfiedPrecondition)")
        /**
            2.如果依赖集合unsatisfiedPrecondition中元素不在最开始传入的[依赖: 版本范围]字典中，失败。
         */
        for node in unsatisfiedPrecondition {
            guard let originalDependencies = originalDependencies, let version = originalDependencies[node.dependency], version.isSatisfied(by: node.proposedVersion) else{
                return .failure(.internalError(description: "Graph invalid due to forward dependencies not satisfied"))
            }
        }
        
        /**
            2.如果不存在白名单，或白名单为空，或lastResolved不存在，直接返回成功
         */
        guard let whitelist = whitelist, !whitelist.isEmpty, let lastResolved = lastResolved else {
            return .success(self)
        }

        // 把白名单或其依赖项中的每个节点加到白名单nodeWhitelist中
        var nodeWhitelist = Set<DependencyNode>()
        allNodes
            .filter { whitelist.contains($0.dependency.name) }
            .forEach { node in
                nodeWhitelist.insert(node)
                if let nestedDependencies = edges[node] {
                    nodeWhitelist.formUnion(nestedDependencies)
                }
            }

        
        var filteredGraph = self
        
        /**
            对于图中所有节点
                ｜如果在白名单中，什么也不做
                ｜如果不在白名单中
                    ｜如果它不在白名单中，并且不在lastResolved中（即不存在以前的版本），则从返回的图中删除它
                    ｜如果它不在白名单中，并且在lastResolved中（即有存在以前的版本），那么它们应该匹配
         */
        for node in allNodes {
            guard !nodeWhitelist.contains(node) else {
                continue
            }

            guard let lastVersion = lastResolved[node.dependency] else {
                // 如果它不在白名单中，并且不在lastResolved中（即不存在以前的版本），则从返回的图中删除它
                filteredGraph.allNodes.remove(node)
                filteredGraph.edges.removeValue(forKey: node)
                continue
            }

            // 如果它不在白名单中，并且在lastResolved中（即有存在以前的版本），那么它们应该匹配
            if lastVersion != node.proposedVersion {
                return .failure(.unsatisfiableDependencyList(whitelist))
            }
        }
        return .success(filteredGraph)
    }
    
}


/// A node in, or being considered for, an acyclic dependency graph.
private final class DependencyNode {
    /// 这个节点代表的依赖
    let dependency: Dependency

    /// 这个节点对应依赖的版本范围
    var versionSpecifier: VersionSpecifier

    /// 依赖的父节点，这个节点对应依赖的版本范围由父节点决定
    var parent: DependencyNode?

    /// 这个节点代表的固定版本
    ///这个版本仅仅是“提议的”，因为它取决于图的最终解析结果，以及是否存在“更好的”图。
    let proposedVersion: PinnedVersion


    ///  节点本身的子依赖
    var dependencies: Set<DependencyNode> = []
    
    
    // 节点本身的前置依赖
    var forwardDependencies:[Dependency : VersionSpecifier] = [:]
    

    init(dependency: Dependency, proposedVersion: PinnedVersion, versionSpecifier: VersionSpecifier, parent: DependencyNode?, forwardDependencies:[Dependency : VersionSpecifier]?) {
        
        precondition(versionSpecifier.isSatisfied(by: proposedVersion))
        
        self.dependency = dependency
        self.proposedVersion = proposedVersion
        self.versionSpecifier = versionSpecifier
        self.parent = parent
        self.forwardDependencies = forwardDependencies ?? [:]
    }
}


extension DependencyNode: Hashable {
    fileprivate func hash(into hasher: inout Hasher) {
        hasher.combine(dependency)
    }
}



extension DependencyNode: Comparable {
    fileprivate static func < (_ lhs: DependencyNode, _ rhs: DependencyNode) -> Bool {
        
        // 从PinnedVersion变成SemanticVersion类型
        let leftSemantic = SemanticVersion.from(lhs.proposedVersion).value ?? SemanticVersion(0, 0, 0)
        let rightSemantic = SemanticVersion.from(rhs.proposedVersion).value ?? SemanticVersion(0, 0, 0)
        
        // 先尝试更高版本。
        return leftSemantic > rightSemantic
    }

    static func == (_ lhs: DependencyNode, _ rhs: DependencyNode) -> Bool {
        guard lhs.dependency == rhs.dependency else { return false }

        let leftSemantic = SemanticVersion.from(lhs.proposedVersion).value ?? SemanticVersion(0, 0, 0)
        let rightSemantic = SemanticVersion.from(rhs.proposedVersion).value ?? SemanticVersion(0, 0, 0)
        
        return leftSemantic == rightSemantic
    }
}


extension DependencyNode: CustomStringConvertible {
    fileprivate var description: String {
        return "\(dependency) @ \(proposedVersion))"
    }
}


