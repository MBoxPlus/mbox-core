//
//  Env+Show.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/10/11.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension MBCommander.Env {
    dynamic
    public func instance(for section: MBCommanderEnv.Type) -> MBCommanderEnv {
        return section.init()
    }

    // MARK: - API
    public func showAPI(_ sections: [MBCommanderEnv.Type]) throws {
        var api = [String: Any]()
        for section in sections {
            let obj = instance(for: section)
            guard let value = try obj.APIData() else {
                continue
            }
            api[section.title] = value
        }
        UI.log(api: api)
    }

    // MARK: - Text
    public func outputSection(_ section: MBCommanderEnv.Type, row: Row) {
        let line = formatTable([row]).first!.trimmed
        if section.showTitle {
            let title = section.title.convertCamelCased()
            UI.log(info: "[\(title)]: \(line)")
        } else {
            UI.log(info: line)
        }
    }

    public func outputSection(_ section: MBCommanderEnv.Type, rows: [Row]) {
        if section.showTitle {
            let title = section.title.convertCamelCased()
            UI.log(info: "[\(title)]:")
        }

        for i in formatTable(rows) {
            UI.log(info: i)
        }
    }

    public func showText(_ sections: [MBCommanderEnv.Type]) throws {
        for (index, section) in sections.enumerated() {
            let obj = instance(for: section)
            if let row = try obj.textRow() {
                outputSection(section, row: row)
            } else if let rows = try obj.textRows(), rows.count > 0 {
                outputSection(section, rows: rows)
            } else {
                continue
            }
            if index < sections.count - 1 {
                UI.log(info: "")
            }
        }
    }

    // MARK: - Plain
    public func showPlain(_ section: MBCommanderEnv.Type) throws {
        let obj = instance(for: section)
        guard let value = try obj.plainData() else {
            return
        }
        UI.log(api: value)
    }
}
