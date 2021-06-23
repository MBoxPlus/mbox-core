//
//  Bundle+URLScheme.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/5/9.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation

extension Bundle {
    public var urlSchemes: [String] {
        guard let types = infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return []
        }
        return types.flatMap { type -> [String] in
            return (type["CFBundleURLSchemes"] as? [String] ?? []).map { $0.lowercased() }
        }
    }

}
