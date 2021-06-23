//
//  Operator.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/6/12.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

@discardableResult
public func <<<T>(left: inout Array<T>, right: T) -> Array<T> {
    left.append(right)
    return left
}

@discardableResult
public func <<<T>(left: inout Array<T>, right: Array<T>) -> Array<T> {
    left.append(contentsOf: right)
    return left
}

@discardableResult
public func <<(left: inout String, right: String) -> String {
    left.append(right)
    return left
}

infix operator <<<

@discardableResult
public func <<<(left: inout String, right: String) -> String {
    left.append("\n" + right)
    return left
}
