//
//  Doc.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/8/27.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation

extension MBCommander {
    open class Doc: MBCommander {
        open class override var description: String? {
            return "Output all commands"
        }

        open override class var options: [Option] {
            var options = super.options
            options << Option("output-path", description: "Output to the file")
            return options
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("markdown", description: "Output with markdown format")
            return flags
        }

        open var markdown: Bool = false
        open var outputPath: String?
        open lazy var fileHandle: FileHandle? = {
            guard var path = self.outputPath else { return nil }
            if !path.hasPrefix("/") {
                path = FileManager.pwd.appending(pathComponent: path)
            }
            try? FileManager.default.removeItem(atPath: path)
            guard FileManager.default.createFile(atPath: path, contents: nil),
                  let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) else {
                return nil
            }
            return handle
        }()

        open override func setup() throws {
            self.markdown = self.shiftFlag("markdown")
            self.outputPath = self.shiftOption("output-path")
            try super.setup()
        }

        open override func run() throws {
            try super.run()
            self.output(group: MBCommanderGroup.shared)
            try self.fileHandle?.close()
        }

        // MARK: - Output
        open func output(group: MBCommanderGroup) {
            self.outputDescription(group: group)
            for (_, subgroup) in group.subGroups.sorted(by: \.key) {
                self.output(group: subgroup)
            }
        }

        open func outputDescription(group: MBCommanderGroup) {
            if !shouldOutput(group) {
                return
            }
            let command = group.command!

            self.output(command: group.fullCmdName, arguments: command.arguments)
            self.output {
                if let cmdDesc = command.description {
                    self.output(description: cmdDesc)
                }

                self.output(arguments: command.arguments)

                let options = self.options(for: command)
                self.output(options: options)


                let flags = self.flags(for: command)
                self.output(flags: flags)

                if let example = command.example {
                    self.output(example: example)
                }
            }
            self.output(string: "")
        }

        func shouldOutput(_ group: MBCommanderGroup) -> Bool {
            let command = group.command!
            if command.arguments.count > 0 {
                return true
            }
            if group.subGroups.isEmpty {
                return true
            }
            return false
        }

        func output(command: [String], arguments: [Argument]) {
            var command = ["mbox"] + command
            if !self.markdown {
                command = command.map { $0.ANSI(.green) }
            }

            var args = arguments.map { (arg) -> String in
                var string = arg.name.uppercased()
                if arg.plural {
                    string.append(" [...]")
                }
                if !arg.required {
                    string = "[\(string)]"
                }
                return string
            }
            if !self.markdown {
                args = args.map { $0.ANSI(.black, bright: true) }
            }

            let string: String
            if self.markdown {
                string = """
## \(command.joined(separator: " "))

```
$ \((command + args).joined(separator: " "))
```
"""
            } else {
                string = """
$ \((command + args).joined(separator: " "))
"""
            }
            output(string: string)
        }

        func output(description: String)  {
            output(string: description)
        }

        func output(arguments: [Argument]) {
            if arguments.isEmpty {
                return
            }
            output(title: "Arguments:") {
                self.output(table: arguments.map { desc(for: $0) })
            }
        }

        func output(options: [Option]) {
            if options.isEmpty {
                return
            }
            output(title: "Options:") {
                self.output(table: options.sorted(by: \.name).map { desc(for: $0) })
            }
        }

        func output(flags: [Flag]) {
            if flags.isEmpty {
                return
            }
            output(title: "Flags:") {
                self.output(table: flags.sorted(by: \.name).map { desc(for: $0) })
            }
        }

        func output(example: String) {
            output(title: "Example:") {
                output(block: example, language: "bash")
            }
        }

        // MARK: - Data
        func options(for command: MBCommander.Type) -> [Option] {
            var allOptions = command.options
            let superCommand = command.superclass() as! MBCommander.Type
            allOptions.removeAll(superCommand.options)
            return allOptions
        }

        func flags(for command: MBCommander.Type) -> [Flag] {
            var allFlags = command.flags
            let superCommand = command.superclass() as! MBCommander.Type
            allFlags.removeAll(superCommand.flags)
            return allFlags
        }

        // MARK: - Format
        func desc(for argument: Argument) -> [String] {
            let column1 = argument.name.uppercased()
            var column2 = argument.required ? "" : "[Optional] ".ANSI(.cyan)
            if let description = argument.description {
                column2.append(description)
            }
            return [column1, column2]
        }

        func desc(for option: Option) -> [String] {
            let column1: String
            if let flag = option.flag {
                column1 = "-\(flag)"
            } else {
                column1 = ""
            }
            let column2 = "--" + option.name
            var column3 = ""
            if let description = option.description {
                column3 = description
            }
            return [column1, column2, column3]
        }

        func filter(table: [[String]]) -> ([[String]], [Int]) {
            guard let firstRow = table.first else {
                return (table, [])
            }

            var justifications = [Int]()
            for index in 0 ..< firstRow.count {
                let sizes = table.map { columns -> Int in
                    let column = columns[index]
                    return column.noANSI.count
                }
                justifications << sizes.max()!
            }

            var result = [[String]]()
            for line in table {
                var items = [String]()
                for (index, item) in line.enumerated() {
                    if justifications[index] == 0 {
                        continue
                    }
                    items.append(item)
                }
                if items.count > 0 {
                    result.append(items)
                }
            }
            return (result, justifications.filter { $0 != 0 })
        }

        func format(table: [[String]], justifications: [Int]) -> [String] {
            return table.map { columns -> String in
                var justColumns = ""
                for (index, column) in columns.enumerated() {
                    let max = justifications[index]
                    if max == 0 { continue }
                    if index == columns.count - 1 {
                        justColumns << column
                        continue
                    } else {
                        justColumns << column.ljust(max + column.count - column.noANSI.count)
                    }
                    if index == columns.count - 3 {
                        justColumns << (column.count == 0 ? "  " : ", ")
                    } else if index == columns.count - 2 {
                        justColumns << "    "
                    }
                }
                return justColumns
            }
        }

        var titleLevel: Int = 2
        func output(title: String? = nil, block: ()->()) {
            titleLevel += 1
            if let title = title {
                self.output(string: "")
                if self.markdown {
                    self.output(string: "#" * titleLevel + " " + title)
                } else {
                    self.output(string: title)
                }
            }
            UI.indentLog(flag: .info, block: block)
            titleLevel -= 1
        }

        func output(block: String, language: String?) {
            let string: String
            if self.markdown {
                string = """
```\(language ?? "")
\(block)
```\n
"""
            } else {
                string = block.replacingOccurrences(of: "(?m)^(#.*)$", with: "$1".ANSI(.cyan).ANSI(.italic), options: .regularExpression)
                    .replacingOccurrences(of: "(?m)^\\$ (.*)$", with: "\\$ " + "$1".ANSI(.green), options: .regularExpression)
            }
            output(string: string)
        }

        func output(text: String) {
            output(string: text)
        }

        func output(table: [[String]]) {
            let (table, sizes) = self.filter(table: table)
            var strings = [String]()
            if self.markdown {
                strings << "<table>"
                for items in table {
                    strings << "  <tr>"
                    for (index, item) in items.enumerated() {
                        if index < items.count - 1 {
                            strings << "    <td style=\"white-space: nowrap\">"
                        } else {
                            strings << "    <td>"
                        }
                        if item.count > 0 {
                            strings << "      \(item)"
                        }
                        strings << "    </td>"
                    }
                    strings << "  </tr>"
                }
                strings << "</table>"
            } else {
                strings = format(table: table, justifications: sizes)
            }
            output(string: strings.joined(separator: "\n"))
        }

        func output(string: String) {
            let string = self.markdown ? string.noANSI : string
            if let file = self.fileHandle {
                let string = string + "\n"
                file.write(string.data(using: .utf8)!)
            } else {
                UI.log(info: string)
            }
        }
    }
}
