//
//  DispatchGroup.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/12/18.
//  Copyright © 2018 Bytedance. All rights reserved.
//

import Foundation

extension DispatchGroup {
    public static func wait(_ block: ((DispatchGroup)->Void)) {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        block(dispatchGroup)
        dispatchGroup.wait()
    }
}
