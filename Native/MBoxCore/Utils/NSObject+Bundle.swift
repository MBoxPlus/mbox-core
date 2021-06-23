//
//  NSObject+Bundle.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/9/2.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation

var kBundleKey: UInt8 = 0
extension NSObject {
    public var bundle: Bundle {
        set {
            associateObject(base: self, key: &kBundleKey, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &kBundleKey) { () -> Bundle in
                return type(of: self).bundle
            }
        }
    }
    
    public class var bundle: Bundle {
        get {
            return Bundle(for: self)
        }
    }
}
