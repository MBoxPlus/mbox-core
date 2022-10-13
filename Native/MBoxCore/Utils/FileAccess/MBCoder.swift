
//
//  MBCoder.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/9/4.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

public class MBCoder {
    func decode(string: String) throws -> Any? {
        throw NSError(domain: "MBCoder Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "`MBCoder.decode` needs to be implemented."])
    }

    func encode(object: Any, sortedKeys: Bool, prettyPrinted: Bool) throws -> String {
        throw NSError(domain: "MBCoder Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "`MBCoder.encode` needs to be implemented."])
    }
}
