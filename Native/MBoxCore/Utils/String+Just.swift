//
//  String+Just.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/6/12.
//  Copyright © 2019 bytedance. All rights reserved.
//

import Foundation

extension String {
    public func rjust(_ length: Int, pad: String = " ") -> String {
        if self.count >= length {
            return self
        }
        let rightPadded = self.padding(toLength:max(count, length), withPad:pad, startingAt:0)
        return "".padding(toLength:length, withPad:rightPadded, startingAt:count % length)
    }

    public func ljust(_ length: Int, pad: String = " ") -> String {
        if self.count >= length {
            return self
        }
        return self.padding(toLength:length, withPad:pad, startingAt:0)
    }

    public func just(length: Int, pad: String = " ") -> String {
        if self.count <= length {
            return self
        }
        let rightPadded = self.padding(toLength:max(count, length), withPad:pad, startingAt:0)
        return "".padding(toLength:length, withPad:rightPadded, startingAt:(length+count)/2 % length)
    }
}

public class Row {
    public var selected: Bool = false
    public var selectedPrefix: String = "=>"
    public var unselectedPrefix: String = ""
    public var columns: [Any]
    public var subRows: [Row]?
    public var text: String = ""
    public convenience init() {
        self.init(columns: [])
    }
    public convenience init(column: String) {
        self.init(columns: [column])
    }
    public init(columns: [Any]) {
        self.columns = columns
    }
    public var description: [String] {
        var v = [text]
        if let sub = subRows?.flatMap(\.description) {
            v.append(contentsOf: sub)
        }
        return v
    }
}

public func formatTable(_ rows: [Row], separator: String = "  ") -> [String] {
    formatTable(rows, indent: 4)
    return rows.flatMap(\.description)
}

private func formatTable(_ rows: [Row], indent: Int, separator: String = "  ") {
    let result: [String]
    let lines = rows.map(\.columns)
    if let rows = lines as? [[[String]]] {
        result = formatTable(rows, separator: separator)
    } else if let rows = lines as? [[String]] {
        result = formatTable(rows, separator: separator)
    } else {
        return
    }
    for (i, row) in rows.enumerated() {
        let prefix: String
        if row.selected {
            prefix = max(0, indent - row.selectedPrefix.noANSI.count - 1) * " " + row.selectedPrefix + " "
        } else {
            prefix = max(0, indent - row.unselectedPrefix.noANSI.count - 1) * " " + row.unselectedPrefix + " "
        }
        row.text = prefix + result[i]
    }
    let subRows = rows.compactMap(\.subRows).flatMap { $0 }
    if subRows.count > 0 {
        formatTable(subRows, indent: indent + 4, separator: separator)
    }
}

private func formatTable(_ rows: [[[String]]], separator: String = "  ") -> [String] {
    guard rows.count > 0 else {
        return [""]
    }

    let maxColumn = rows.map { $0.count }.max()!

    var maxs = [Int]()
    for index in 0..<maxColumn {
        maxs << rows.map { $0.count > index ? $0[index].count : 0 }.max()!
    }

    var infos = [[String]]()
    for line in rows {
        var info = [String]()
        for (index, max) in maxs.enumerated() {
            if max == 0 { continue }
            let items = line.count > index ? line[index] : []
            info << items
            if items.count < max {
                info << Array(expression: "", count: max - items.count)
            }
        }
        infos << info
    }

    return formatTable(infos, separator: separator)
}

private func formatTable(_ rows: [[String]], separator: String = "  ") -> [String] {
    guard let firstRow = rows.first else {
        return [""]
    }

    var justifications = [Int]()
    for index in 0 ..< firstRow.count {
        let sizes = rows.map { columns -> Int in
            var column = ""
            if index < columns.count {
                column = columns[index]
            }
            return column.noANSI.count
        }
        justifications << sizes.max()!
    }

    return rows.map { columns -> String in
        var justColumns = [String]()
        for (index, column) in columns.enumerated() {
            if index >= justifications.count {
                justColumns << ""
            } else {
                justColumns << column.ljust(justifications[index] + column.count - column.noANSI.count)
            }
        }
        return justColumns.joined(separator: separator)
    }
}
