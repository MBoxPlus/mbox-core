//
//  OperatingSystemVersion.swift
//  MBoxCore
//
//  Created by Whirlwind on 2021/1/14.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension OperatingSystemVersion: CustomStringConvertible {
    public var description: String {
        return "\(self.majorVersion).\(self.minorVersion).\(self.patchVersion)"
    }
}
