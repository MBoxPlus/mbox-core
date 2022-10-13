//
//  Env.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/9/22.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

public protocol MBCommanderEnv {
    static var supportedAPI: [MBCommander.Env.APIType] { get }
    static var title: String { get }
    static var showTitle: Bool { get }
    static var indent: Bool { get }

    init()

    func textRow() throws -> Row?
    func textRows() throws -> [Row]?
    func APIData() throws -> Any?
    func plainData() throws -> [String]?
}

extension MBCommanderEnv {
    public static var showTitle: Bool { return true }
    public static var indent: Bool { return true }
    public func textRow() throws -> Row? { return nil }
    public func textRows() throws -> [Row]? { return nil }
    public func APIData() throws -> Any?  { return nil }
    public func plainData() throws -> [String]?  { return nil }
}

extension MBCommander {
    @objc(MBCommanderEnv)
    open class Env: MBCommander {
        public enum APIType {
            case none
            case api
            case plain
        }

        open override class var options: [Option] {
            var options = super.options
            options << Option("only", description: "Only show information.", valuesBlock: { return self.sections.map { $0.title } })
            return options
        }

        open class override var description: String? {
            return "Show MBox Environment"
        }

        dynamic
        open override func setup() throws {
            self.only = (self.shiftOptions("only") ?? ["all"]).map { $0.lowercased() }
            try super.setup()
        }

        open var only: [String] = ["all"]
        open var sections: [MBCommanderEnv.Type] = []

        open override func validate() throws {
            try super.validate()
            if MBProcess.shared.apiFormatter == .plain {
                if self.sections.count > 1 {
                    throw ArgumentError.conflict("It is not allowed with multiple sections when using `--api=plain`.")
                }
            }
            var sections = [MBCommanderEnv.Type]()
            let allSections = Self.sections
            for only in self.only {
                if only == "all" {
                    sections.append(contentsOf: allSections)
                } else if let section = allSections.first(where: { $0.title.lowercased() == only }) {
                    sections.append(section)
                }
            }
            for section in sections {
                if !self.sections.contains(where: { $0 == section }) {
                    self.sections.append(section)
                }
            }
        }

        dynamic
        open override func run() throws {
            try super.run()
            switch MBProcess.shared.apiFormatter {
            case .none:
                try self.showText(sections)
            case .plain:
                if let section = sections.first {
                    try self.showPlain(section)
                }
            default:
                try self.showAPI(sections)
            }
        }

        dynamic
        open class var allSections: [MBCommanderEnv.Type] {
            return [System.self, Plugins.self]
        }

        open class var sections: [MBCommanderEnv.Type] {
            let apiType: APIType
            switch MBProcess.shared.apiFormatter {
            case .none:
                apiType = .none
            case .plain:
                apiType = .plain
            default:
                apiType = .api
            }
            return self.allSections.filter {
                $0.supportedAPI.contains(apiType)
            }
        }

        dynamic
        public func instance(for section: MBCommanderEnv.Type) -> MBCommanderEnv {
            return section.init()
        }
    }
}
