//
//  Finder.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/4/3.
//  Copyright © 2019 Bytedance. All rights reserved.
//

import Foundation
import AppKit

open class Finder: ExternalApp {
    override init(name: String? = nil) {
        super.init(name: name ?? "Finder")
    }

    @discardableResult
    open override func open(files: [String]) -> Bool {
        let urls = files.map { URL(fileURLWithPath:$0) }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        return true
    }

    @discardableResult
    open override func open(directories: [String]) -> Bool {
        for directory in directories {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath:directory)
        }
        return true
    }
}
