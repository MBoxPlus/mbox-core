//
//  ResultExtension.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/4/19.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

public extension Result {
    var value: Success? {
        switch self {
        case .success(let v):
            return v
        default:
            return nil
        }
    }

    var error: Failure? {
        switch self {
        case .failure(let error):
            return error
        default:
            return nil
        }
    }
}
