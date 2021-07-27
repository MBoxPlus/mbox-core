//
//  MBAccount.swift
//  MBoxCore
//
//  Created by Yao Li on 2020/8/27.
//  Copyright © 2020 bytedance. All rights reserved.
//

public protocol MBUserProtocol {
    var nickname: String? { get }
    var email: String? { get }
}

public class MBUser {

    dynamic
    public static var current: MBUserProtocol? {
        return nil
    }

}
