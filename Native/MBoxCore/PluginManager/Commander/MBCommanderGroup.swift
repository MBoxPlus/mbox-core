//
//  MBCommanderGroup.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/6/6.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation
import Signals
import ObjCCommandLine

public class MBCommanderGroup: NSObject {

    public static let shared = MBCommanderGroup("mbox", MBCommander.MBox.self)

    dynamic
    open class func preParse(_ parser: ArgumentParser) {
    }

    public var name: String
    public lazy var cmdName: String = {
        return self.command?.name ?? name.convertKebabCased()
    }()

    public lazy var fullCmdName: [String] = {
        guard let parent = self.parentGroup else { return [] }
        return parent.fullCmdName + [self.cmdName]
    }()

    public var subGroups: [String: MBCommanderGroup] = [:]
    public var command: MBCommander.Type?

    public func addCommand(_ command: MBCommander.Type) {
        self.group(for: command, create: true)
    }

    public func command(for parser: ArgumentParser) -> MBCommanderGroup? {
        guard let cmd = parser.argument() else { return self }
        let alias: String? = try! parser.option(for: "expand-alias")
        var current: MBCommanderGroup? = self.subgroup(for: cmd)
        if current == nil {
            if let alias = alias, !alias.isEmpty {
                let args: [String] = argumentParse(alias)
                parser.unshift(arguments: args)
                parser.rawArguments.remove(at: 1)
                parser.rawArguments.insert(contentsOf: args, at: 1)
                current = self
            }
        }
        while current != nil, let cmd = parser.argument() {
            let next = current?.subgroup(for: cmd)
            if next == nil {
                parser.unshift(argument: cmd)
                break
            }
            current = next
        }
        return current
    }

    @discardableResult
    public func group(for command: MBCommander.Type, create: Bool = false) -> MBCommanderGroup? {
        let group = self.group(for: self.cmdKlassNames(for: command), create: create)
        if create {
            group?.command = command
        }
        return group
    }

    public func group(for commandNames: [String], create: Bool = false) -> MBCommanderGroup? {
        var names = commandNames
        let name = names.removeFirst()
        var group = self.subGroups[name]
        if group == nil, create {
            group = MBCommanderGroup(name)
            group!.parentGroup = self
            self.subGroups[name] = group
        }
        if names.isEmpty {
            return group
        } else {
            return group?.group(for: names, create: create)
        }
    }

    // MARK: - private
    init(_ name: String, _ command: MBCommander.Type? = nil) {
        self.name = name
        self.command = command
    }

    private func cmdKlassNames(for command: MBCommander.Type) -> [String] {
        let fullName = String(reflecting: command)
        return Array(fullName.split(separator: ".").dropFirst().dropFirst().map { String($0) })
    }

    private func subgroup(for cmd: String) -> MBCommanderGroup? {
        return self.subGroups.values.first { $0.cmdName == cmd }
    }

    private weak var parentGroup: MBCommanderGroup?

    private func log(_ tabNumber: Int = 0) {
        var tt = "", cnt = tabNumber
        while cnt != 0 {
            tt += "\n"
        }
        for nxt in subGroups {
            print("\(tt) - \(nxt.value)")
        }
    }
}
