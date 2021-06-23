//
//  UpdateTests.swift
//  MBoxCoreTests
//
//  Created by 詹迟晶 on 2019/12/11.
//  Copyright © 2019 bytedance. All rights reserved.
//

import XCTest
import Nimble
import MBoxCore

extension MBCommander {
    class MockUpdate: MBCommander.Update {
        var appBundlePath: String!
        open override func appBundle() throws -> Bundle {
            let path = temporaryURL(forPurpose: appBundlePath).path
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            let info = ["CFBundleShortVersionString": "1.0.0"]
            (info as NSDictionary).write(toFile: path.appending(pathComponent: "Info.plist"), atomically: true)
            return Bundle(path: path)!
        }
    }
}

class UpdateTests: XCTestCase {

    let tmp = temporaryURL(forPurpose: "Update").path

    override func setUp() {
        UI.verbose = true
        try! FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true, attributes: nil)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tmp)
    }

    func testCMD() {
        let cmd = try! MBCommander.MockUpdate(argv: ArgumentParser())
        cmd.appBundlePath = tmp.appending(pathComponent: "MBox.app")
        try! cmd.performAction()
    }
}
