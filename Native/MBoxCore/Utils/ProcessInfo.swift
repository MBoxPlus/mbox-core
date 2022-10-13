//
//  ProcessInfo.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/9/9.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension ProcessInfo {
    public func environment(name: String, remove: Bool = false) -> String? {
        let value = self.environment[name]
        if value != nil, remove {
            _ = name.withCString {
                unsetenv($0)
            }
        }
        return value
    }

    @discardableResult
    public func removeEnvironment(name: String) -> String? {
        let value = self.environment[name]
        if value != nil {
            _ = name.withCString {
                unsetenv($0)
            }
        }
        return value
    }

    public func setEnvironment(name: String, value: String) {
        _ = name.withCString { cname in
            value.withCString { cvalue in
                setenv(cname, cvalue, 1)
            }
        }
    }
}
