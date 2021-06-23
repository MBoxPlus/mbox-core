//
//  URL+Query.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/24.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation

extension URL {
    public var queryItems: [String: String]? {
        let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        guard let items = components?.queryItems, items.count > 0 else {
            return nil
        }
        var result = [String: String]()
        for item in items {
            result[item.name] = item.value
        }
        return result
    }

}
