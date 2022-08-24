//
//  TestResolver.swift
//  MBoxCore
//
//  Created by snowtiger on 2021/11/3.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

public struct TestResolver {
    
    
    public static let shared = TestResolver()
    
    
    public func executeTest() -> Void {
        test_1(Resolver.self)
        test_2(Resolver.self)
        test_3(Resolver.self)
        test_4(Resolver.self)
        test_5(Resolver.self)
        test_6(Resolver.self)
        test_7(Resolver.self)
        test_8(Resolver.self)
        test_9(Resolver.self)
        test_10(Resolver.self)
        test_11(Resolver.self)
        test_12(Resolver.self)
        test_13(Resolver.self)

    }


    private func expect(_ result : Result<[Dependency : PinnedVersion],ResolverError>, _ targetDictory : [Dependency : PinnedVersion],_ message : String = "") -> Void {
        switch  result{
            case let .failure(error):
                print("\(message) false")
                print(error)
                return //false
            case let .success(dependencies):
                for (dependency, version) in dependencies{
                    guard let targetVersion = targetDictory[dependency], targetVersion == version else {
                        print("\(message) false")
                        return //false
                    }
                }

        }
        print("\(message) true")
        return //true
    }

    private func test_1(_ resolverType: ResolverProtocol.Type){
        //print("解析简单的依赖:")
        
        let db: DB = [
            github1: [
                .v0_1_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
            ],
            github2: [
                .v1_0_0: [:],
            ],
            ]

        let resolved  = db.resolve(resolverType, [ github1: .exactly(.v0_1_0) ])

        let target : [Dependency : PinnedVersion] = [
            github2: .v1_0_0,
            github1: .v0_1_0,
        ]
        
        expect(resolved, target ,"解析简单的依赖")
        
    }







    private func test_2(_ resolverType: ResolverProtocol.Type){
        //print("解析到最新的匹配版本:")
        let db: DB = [
            github1: [
                .v0_1_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
                .v1_0_0: [
                    github2: .compatibleWith(.v2_0_0),
                ],
                .v1_1_0: [
                    github2: .compatibleWith(.v2_0_0),
                ],
            ],
            github2: [
                .v1_0_0: [:],
                .v2_0_0: [:],
                .v2_0_1: [:],
            ],
            ]

        let resolved = db.resolve(resolverType, [ github1: .any ])
        
        let target : [Dependency : PinnedVersion] =  [
            github2: .v2_0_1,
            github1: .v1_1_0,
        ]
        
        expect(resolved, target ,"解析到最新的匹配版本")
        

    }


    private func test_3(_ resolverType: ResolverProtocol.Type){
        //print("当给定特定的依赖项时，应该解析子集:")
        let db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
                .v1_1_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
            ],
            github2: [
                .v1_0_0: [ github3: .compatibleWith(.v1_0_0) ],
                .v1_1_0: [ github3: .compatibleWith(.v1_0_0) ],
            ],
            github3: [
                .v1_0_0: [:],
                .v1_1_0: [:],
                .v1_2_0: [:],
            ],
            git1: [
                .v1_0_0: [:],
            ],
            ]

        let resolved = db.resolve(resolverType,
                                  [
                                    github1: .any,
                                    // Newly added dependencies which are not inclued in the
                                    // list should not be resolved.
                                    git1: .any,
                                    ],
                                  resolved: [ github1: .v1_0_0, github2: .v1_0_0, github3: .v1_0_0 ],
                                  updating: [ github2 ]
        )
        
        let target : [Dependency : PinnedVersion] =  [
            github3: .v1_2_0,
            github2: .v1_1_0,
            github1: .v1_0_0,
        ]
        
        expect(resolved, target ,"当给定特定的依赖项时，应该解析子集")
        
    }


    private func test_4(_ resolverType: ResolverProtocol.Type){
        //print("当父依赖被标记为更新时，更新根列表中嵌套的依赖项:")
        let db: DB = [
            github1: [
                .v1_0_0: [
                    git1: .compatibleWith(.v1_0_0)
                ]
            ],
            git1: [
                .v1_0_0: [:],
                .v1_1_0: [:]
            ]
        ]

        let resolved = db.resolve(resolverType,
                              [ github1: .any, git1: .any],
                              resolved: [ github1: .v1_0_0, git1: .v1_0_0 ],
                              updating: [ github1 ])
        
        let target : [Dependency : PinnedVersion] =  [
            github1: .v1_0_0,
            git1: .v1_1_0
        ]

        expect(resolved, target ,"当父依赖被标记为更新时，更新根列表中嵌套的依赖项")
    }

    private func test_5(_ resolverType: ResolverProtocol.Type){
       // print("当给出不兼容的嵌套版本范围时失败:")
        let db: DB = [
            github1: [
                .v1_0_0: [
                    git1: .compatibleWith(.v1_0_0),
                    github2: .any,
                ],
            ],
            github2: [
                .v1_0_0: [
                    git1: .compatibleWith(.v2_0_0),
                ],
            ],
            git1: [
                .v1_0_0: [:],
                .v1_1_0: [:],
                .v2_0_0: [:],
                .v2_0_1: [:],
            ]
        ]
        let resolved = db.resolve(resolverType, [github1: .any])
        
        expect(resolved, [:] ,"当给出不兼容的嵌套版本范围时失败")
    }

    private func test_6(_ resolverType: ResolverProtocol.Type){
        //print("当版本范围有交集时正确解析:")
     
        let db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .compatibleWith(.v1_0_0)
                ]
            ],
            github2: [
                .v1_0_0: [:],
                .v2_0_0: [:]
            ]
        ]

        let resolved = db.resolve(resolverType, [ github1: .any, github2: .atLeast(.v1_0_0) ])

        let target : [Dependency : PinnedVersion] = [
            github1: .v1_0_0,
            github2: .v1_0_0
        ]
        
        expect(resolved, target ,"当版本范围有交集时正确解析")
    }

    private func test_7(_ resolverType: ResolverProtocol.Type){
       // print("当给定具有约束的特定依赖项时，解析子集:")
     
        let db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
                .v1_1_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
                .v2_0_0: [
                    github2: .compatibleWith(.v2_0_0),
                ],
            ],
            github2: [
                .v1_0_0: [ github3: .compatibleWith(.v1_0_0) ],
                .v1_1_0: [ github3: .compatibleWith(.v1_0_0) ],
                .v2_0_0: [:],
            ],
            github3: [
                .v1_0_0: [:],
                .v1_1_0: [:],
                .v1_2_0: [:],
            ],
            ]

        let resolved = db.resolve(resolverType,
                                  [ github1: .any ],
                                  resolved: [ github1: .v1_0_0, github2: .v1_0_0, github3: .v1_0_0 ],
                                  updating: [ github2 ]
        )
        
        
        let target : [Dependency : PinnedVersion] = [
            github3: .v1_2_0,
            github2: .v1_1_0,
            github1: .v1_0_0,
        ]
        
        expect(resolved, target ,"当给定具有约束的特定依赖项时，解析子集")
        
    }


    private func test_8(_ resolverType: ResolverProtocol.Type){
        //print("当唯一有效的图不在指定的依赖项中时失败:")
        let db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
                .v1_1_0: [
                    github2: .compatibleWith(.v1_0_0),
                ],
                .v2_0_0: [
                    github2: .compatibleWith(.v2_0_0),
                ],
            ],
            github2: [
                .v1_0_0: [ github3: .compatibleWith(.v1_0_0) ],
                .v1_1_0: [ github3: .compatibleWith(.v1_0_0) ],
                .v2_0_0: [:],
            ],
            github3: [
                .v1_0_0: [:],
                .v1_1_0: [:],
                .v1_2_0: [:],
            ],
            ]
        let resolved = db.resolve(resolverType,
                                  [ github1: .exactly(.v2_0_0) ],
                                  resolved: [ github1: .v1_0_0, github2: .v1_0_0, github3: .v1_0_0 ],
                                  updating: [ github2 ]
        )
        
        expect(resolved, [:] ,"当唯一有效的图不在指定的依赖项中时失败")
        
    }

    private func test_9(_ resolverType: ResolverProtocol.Type){
        //print("解析一个依赖列表，它的依赖由分支名称和SHA指定，SHA是该分支的HEAD:")
        let branch = "development"
        let sha = "8ff4393ede2ca86d5a78edaf62b3a14d90bffab9"
        
        
        var db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .any,
                    github3: .gitReference(sha),
                ],
            ],
            github2: [
                .v1_0_0: [
                    github3: .gitReference(branch),
                ],
            ],
            github3: [
                .v1_0_0: [:],
            ],
            ]
        db.references = [
            github3: [
                branch: PinnedVersion(sha),
                sha: PinnedVersion(sha),
            ],
        ]

        let resolved = db.resolve(resolverType, [ github1: .any, github2: .any ])
        
        
        let target : [Dependency : PinnedVersion] =  [
            github3: PinnedVersion(sha),
            github2: .v1_0_0,
            github1: .v1_0_0,
        ]
        
        expect(resolved, target ,"解析一个依赖列表，它的依赖由分支名称和SHA指定，SHA是该分支的HEAD")
        
    }

    private func test_10(_ resolverType: ResolverProtocol.Type){
       // print("正确排列传递依赖:")
        let db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .any,
                    github3: .any,
                ],
            ],
            github2: [
                .v1_0_0: [
                    github3: .any,
                    git1: .any,
                ],
            ],
            github3: [
                .v1_0_0: [ git2: .any ],
            ],
            git1: [
                .v1_0_0: [ github3: .any ],
            ],
            git2: [
                .v1_0_0: [:],
            ],
            ]

        let resolved = db.resolve(resolverType, [ github1: .any ])

        
        let target : [Dependency : PinnedVersion] =  [
            git2: .v1_0_0,
            github3: .v1_0_0,
            git1: .v1_0_0,
            github2: .v1_0_0,
            github1: .v1_0_0,
        ]
        
        expect(resolved, target ,"正确排列传递依赖")

    }

    private func test_11(_ resolverType: ResolverProtocol.Type){
        //print("如果没有版本匹配需求，并且存在预发布版本，应该失败:")
        let db: DB = [
            github1: [
                .v1_0_0: [:],
                .v2_0_0_beta_1: [:],
                .v2_0_0: [:],
                .v3_0_0_beta_1: [:],
            ],
            ]


            let resolved1 = db.resolve(resolverType, [ github1: .atLeast(.v3_0_0) ])
        
            let resolved2 = db.resolve(resolverType, [ github1: .compatibleWith(.v3_0_0) ])
  
            let resolved3 = db.resolve(resolverType, [ github1: .exactly(.v3_0_0) ])
            expect(resolved1, [:] ,"如果没有版本匹配需求，并且存在预发布版本，应该失败")
            expect(resolved2, [:] ,"如果没有版本匹配需求，并且存在预发布版本，应该失败")
            expect(resolved3, [:] ,"如果没有版本匹配需求，并且存在预发布版本，应该失败")
        
    }
    
    
    private func test_12(_ resolverType: ResolverProtocol.Type){
        var db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .any,
                    github3: .any,
                ],
            ],
            github2: [
                .v1_0_0: [
                    github3: .any,
                    git1: .any,
                ],
            ],
            github3: [
                .v1_0_0: [ git2: .any ],
            ],
            github4: [
                .v1_0_0: [ : ],
            ],
            git1: [
                .v1_0_0: [ github3: .any ],
            ],
            git2: [
                .v1_0_0: [:],
            ],
            ]

        db.forwarddependencies = [
            github3: [
                .v1_0_0: [ git1: .any ],
            ],
            github4: [
                .v1_0_0: [ git3: .any ],
            ],
            ]
        let resolved = db.resolve(resolverType, [ github1: .any ,github4: .any])

        
        let target : [Dependency : PinnedVersion] =  [
            git2: .v1_0_0,
            github3: .v1_0_0,
            git1: .v1_0_0,
            github2: .v1_0_0,
            github1: .v1_0_0,
        ]
        
        expect(resolved, target ,"正确解析前置依赖")

    }

    private func test_13(_ resolverType: ResolverProtocol.Type){
        var db: DB = [
            github1: [
                .v1_0_0: [
                    github2: .any,
                    github3: .any,
                ],
            ],
            github2: [
                .v1_0_0: [
                    github3: .any,
                    git1: .any,
                ],
            ],
            github3: [
                .v1_0_0: [ git2: .any ],
            ],
            git1: [
                .v1_0_0: [ github3: .any ],
            ],
            git2: [
                .v1_0_0: [:],
            ],
            ]

        db.forwarddependencies = [
            github3: [
                .v1_0_0: [ git2: .any ],
            ],
   
            ]
        let resolved = db.resolve(resolverType, [ github1: .any ])

        
        let target : [Dependency : PinnedVersion] =  [
            git2: .v1_0_0,
            github3: .v1_0_0,
            git1: .v1_0_0,
            github2: .v1_0_0,
            github1: .v1_0_0,
        ]
        
        expect(resolved, target ,"前置依赖不满足")

    }
    
}





