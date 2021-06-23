//
//  NimblePlus.swift
//  MBoxCoreTests
//
//  Created by Whirlwind on 2018/8/22.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation
import Nimble

extension Expectation where T == Bool {
    public func isTrue(description: String? = nil) {
        self.to(beTrue(), description: description)
    }
    public func isFalse(description: String? = nil) {
        self.to(beFalse(), description: description)
    }
}

extension Expectation where T == Any? {
    public func isNil(description: String? = nil) {
        self.to(beNil(), description: description)
    }
    public func isNotNil(description: String? = nil) {
        self.notTo(beNil(), description: description)
    }
}

public func expectFile(_ path1: String, _ path2: String, file: FileString = #file, line: UInt = #line) {
    expect(specFile(path1), file: file, line: line) == specFile(path2)
}

public func temporaryURL(forPurpose purpose: String) -> URL {
    let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
    let path = "\(NSTemporaryDirectory())Tests/\(globallyUniqueString)/\(purpose)"
    return URL(fileURLWithPath: path)
}

func bundleResourcePath() -> String {
    return (Bundle.init(identifier: "com.bytedance.MBoxCoreTests")?.resourcePath)!
}

func specFilePath(_ file: String) -> String {
    var filePath = file
    let bundle = Bundle.init(identifier: "com.bytedance.MBoxCoreTests")
    if !filePath.hasPrefix("/") {
        filePath = (bundle?.path(forResource: filePath, ofType: nil))!
    }
    return filePath
}

func specFile(_ file: String) -> String? {
    let file = specFilePath(file)
    do {
        return try String(contentsOf: URL(fileURLWithPath: file), encoding: .utf8).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    } catch {
        fail("Read file failed `\(error)`")
        return nil
    }
}

