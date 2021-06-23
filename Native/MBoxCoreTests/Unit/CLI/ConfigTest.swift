//
//  ConfigTest.swift
//  MBoxCoreTests
//
//  Created by 詹迟晶 on 2019/12/29.
//  Copyright © 2019 bytedance. All rights reserved.
//

import XCTest
import Nimble
import MBoxCore

extension MBSetting {
    @objc
    open var testString: String? {
        set {
            self.dictionary["testString"] = newValue
        }
        get {
            return self.dictionary["testString"] as? String
        }
    }
}
class ConfigTests: XCTestCase {

    class ConfigMock: MBCommander.Config {
        override func saveSetting(_ setting: MBSetting) {
            // Do nothing
        }
        override func checkSetting(for name: String) -> MBPluginSettingSchema? {
            if let v = super.checkSetting(for: name) { return v }
            if name == "testString" {
                return MBPluginSettingSchema(dictionary: ["id": "testString", "type": MBPluginSettingSchema.MBPluginSettingSchemaTypeName.string.rawValue, "global": true])
            }
            return nil
        }
    }

    override func setUp() {
        UI.logDirectory = temporaryURL(forPurpose: "logs").path
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testShow() {
        MBSetting.global.testString = "MBoxGit"
        let cmd = try! MBCommander.Config(argv: ArgumentParser(arguments: []))
        try! cmd.performAction()
        let logFile = UI.verbLogFilePath!
        let log = try! String(contentsOfFile: logFile)
        try! expect(log.match("\"testString\" *: *\"MBoxGit\"").isEmpty).isFalse()
    }

    func testShowName() {
        MBSetting.global.testString = "MBoxGit"
        let cmd = try! ConfigMock(argv: ArgumentParser(arguments: ["testString"]))
        try! cmd.performAction()
        let logFile = UI.verbLogFilePath!
        let log = try! String(contentsOfFile: logFile)
        try! expect(log.match("testString *: *MBoxGit").isEmpty).isFalse()
    }

    func testInvalidArgument() {
        let cmd = try! ConfigMock(argv: ArgumentParser(arguments: ["testString", "x", "-d"]))
        expect(try cmd.performAction()).to(throwError(ArgumentError.conflict("`--delete` is not allowed for configure mode.")))
    }

    func testDelete() {
        testConfigPlugin()
        let cmd = try! ConfigMock(argv: ArgumentParser(arguments: ["testString", "-d"]))
        expect(try cmd.performAction()).toNot(throwError())
        expect(MBSetting.global.dictionary.has(key: "testString")).isFalse()
    }

    func testConfigPlugin() {
        MBSetting.global.testString = "MBoxGit"
        let cmd = try! ConfigMock(argv: ArgumentParser(arguments: ["testString", "MBoxGit2"]))
        try! cmd.performAction()
        if let plugins = MBSetting.global.dictionary["testString"] as? String {
            expect(plugins) == "MBoxGit2"
        } else {
            fail()
        }
    }
}
