public class UserError: Error, CustomStringConvertible, LocalizedError {
    public var description: String
    public init(_ desc: String? = nil,
                file: StaticString = #file,
                function: StaticString = #function,
                line: UInt = #line) {
        self.description = desc ?? ""
        if !self.description.isEmpty {
            UI.log(verbose: "[RuntimeError]".ANSI(.red) + " \(self.description)", file: file, function: function, line: line)
        }
    }
    public var errorDescription: String? {
        return description
    }
}

public class RuntimeError: CustomStringConvertible, LocalizedError {
    public var description: String
    public var code: Int32
    public init(_ desc: String? = nil, code: Int32 = 100,
                file: StaticString = #file,
                function: StaticString = #function,
                line: UInt = #line) {
        self.description = desc ?? ""
        self.code = code
        if !self.description.isEmpty {
            UI.log(verbose: "[RuntimeError]".ANSI(.red) + " \(self.description)", file: file, function: function, line: line)
        }
    }
    public var errorDescription: String? {
        return description
    }
}

public enum ArgumentError: Equatable, CustomStringConvertible, LocalizedError {
    case missingArgument(String)
    case missingValue(String?)
    /// Value is not unexpect
    case invalidValue(value:String, argument:String?)
    /// Value is not convertible to type
    case invalidType(value:String, type:String, argument:String?)
    case unusedArgument(String)
    case unknownArgument([String])
    case undeclaredArgument(String)
    case invalidCommand(String?)
    case conflict(String)

    public var errorDescription: String? {
        return description
    }

    public var description: String {
        switch self {
        case .missingArgument(let key):
            return "Require argument `\(key)`"
        case .missingValue(let key):
            if let key = key {
                return "Missing value for `\(key)`"
            }
            return "Missing value"
        case .invalidValue(let value, let argument):
            if let argument = argument {
                return "`\(value)` is invalid value for `\(argument)`"
            }
            return "`\(value)` is invalid."
        case .invalidType(let value, let type, let argument):
            if let argument = argument {
                return "`\(value)` is not a valid `\(type)` for `\(argument)`"
            }
            return "`\(value)` is not a `\(type)`"
        case .unusedArgument(let argument):
            return "Unexpected argument `\(argument)`"
        case .unknownArgument(let arguments):
            return "Unknown arguments: \(arguments.map { $0.quoted }.joined(separator: " "))"
        case .undeclaredArgument(let argument):
            return "[DEV] The argument `\(argument)` is undeclared"
        case .invalidCommand(let command):
            return command ?? ""
        case .conflict(let message):
            return message
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (missingArgument(let l), missingArgument(let r)):
            return l == r
        case (missingValue(let l), missingValue(let r)):
            return l == r
        case (invalidValue(let lValue, let lArgument), invalidValue(let rValue, let rArgument)):
            return lValue == rValue && lArgument == rArgument
        case (invalidType(let lValue, let lArgument, let lType), invalidType(let rValue, let rArgument, let rType)):
            return lValue == rValue && lType == rType && lArgument == rArgument
        case (unusedArgument(let l), unusedArgument(let r)):
            return l == r
        case (unknownArgument(let l), unknownArgument(let r)):
            return l == r
        case (undeclaredArgument(let l), undeclaredArgument(let r)):
            return l == r
        case (invalidCommand(let l), invalidCommand(let r)):
            return l == r
        case (conflict(let l), conflict(let r)):
            return l == r
        default:
            return false
        }
    }

}

class Help: CustomStringConvertible {
    let command: MBCommander.Type
    let group: MBCommanderGroup
    let argv: ArgumentParser

    init(command: MBCommander.Type, group: MBCommanderGroup, argv: ArgumentParser) {
        self.command = command
        self.group = group
        self.argv = argv
    }

    func APIDescription(format: MBLoggerAPIFormatter) -> JSONSerializable {
        switch format {
        case .plain:
            return plainDescription
        default:
            return []
        }
    }

    var plainDescription: [String] {
        var commands = [String]()
        for (_, subgroup) in group.subGroups.sorted(by: { $0.key < $1.key }) {
            var line = [subgroup.cmdName]
            if let description = subgroup.command?.description {
                line.append(description)
            }
            commands.append(line.joined(separator: ":"))
        }
        if let command = group.command {
            if let argv = self.argv.last() {
                switch argv {
                case .flag(let name, let sname) where !name.isEmpty && !sname.isEmpty:
                    let flag = command.flags.first { flag in
                        if flag.name == name || flag.disabledName == name {
                            return true
                        }
                        if let flag = flag.flag, sname.contains(flag) {
                            return true
                        }
                        if let flag = flag.disabledFlag, sname.contains(flag) {
                            return true
                        }
                        return false
                    }
                    if flag == nil {
                        if let option = command.options.first(where: { option in
                            if option.name == name {
                                return true
                            }
                            if let flag = option.flag, sname.contains(flag) {
                                return true
                            }
                            return false
                        }) {
                            commands.append(contentsOf: option.values)
                            if let valuesBlock = option.valuesBlock {
                                commands.append(contentsOf: valuesBlock())
                            }
                        }
                    } else {
                        fallthrough
                    }
                case .option(let name) where !name.isEmpty:
                    if let option = command.options.first(where: { $0.name == name }) {
                        commands.append(contentsOf: option.values)
                        if let valuesBlock = option.valuesBlock {
                            commands.append(contentsOf: valuesBlock())
                        }
                    } else {
                        fallthrough
                    }
                default:
                    commands.append(contentsOf: command.autocompletion(argv: self.argv))
                }
            } else {
                commands.append(contentsOf: command.autocompletion(argv: self.argv))
            }
        }
        return commands
    }

    var description: String {
        var output = [String]()

        var usage = (["mbox"] + group.fullCmdName).map { $0.ANSI(.green) }
        let argsDesc = command.arguments.map { (arg) -> String in
            var string = arg.name.uppercased()
            if arg.plural {
                string.append(" [...]")
            }
            if !arg.required {
                string = "[\(string)]"
            }
            return string.ANSI(.black, bright: true)
        }
        usage.append(contentsOf: argsDesc)

        output.append("Usage:".ANSI(.underline))
        output.append("")
        output.append("    $ \(usage.joined(separator: " "))")
        output.append("")
        if let cmdDesc = command.description {
            output.append("      \(cmdDesc)")
            output.append("")
        }

        let subGroups = group.subGroups.filter { $0.value.command?.shouldShowInHelp() == true }
        if subGroups.count > 0 {
            output.append("Commands:".ANSI(.underline))
            output.append("")
            var commands = [[String]]()
            for (_, subgroup) in subGroups.sorted(by: { $0.key < $1.key }) {
                let column1 = "    + \(subgroup.cmdName)".ANSI(.green)
                var column2 = ""
                if let description = subgroup.command?.description {
                    column2 = description
                }
                commands << [column1, column2]
            }
            output.append(contentsOf: format_table(commands))
            output.append("")
        }

        if !command.arguments.isEmpty {
            output.append("Arguments:".ANSI(.underline))
            output.append("")
            var arguments = [[String]]()
            for argument in command.arguments {
                arguments << desc(for: argument)
            }
            output.append(contentsOf: format_table(arguments).map { "    " + $0 })
            output.append("")
        }

        if !command.options.isEmpty {
            output.append("Options:".ANSI(.underline))
            output.append("")
            var options = [[String]]()
            for option in command.options {
                options << desc(for: option)
            }
            output.append(contentsOf: format_table(options).map { "    " + $0 })
            output.append("")
        }

        if !command.flags.isEmpty {
            output.append("Flags:".ANSI(.underline))
            output.append("")
            var flags = [[String]]()
            for flag in command.flags {
                flags << desc(for: flag)
            }
            output.append(contentsOf: format_table(flags).map { "    " + $0 })
            output.append("")
        }

        if let extendDescription = command.extendHelpDescription {
            output.append(extendDescription)
            output.append("")
        }

        return output.joined(separator: "\n")
    }

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

    func format_table(_ rows: [[String]]) -> [String] {
        guard let firstRow = rows.first else {
            return []
        }

        var justifications = [Int]()
        for index in 0 ..< firstRow.count {
            let sizes = rows.map { columns -> Int in
                let column = columns[index]
                return column.noANSI.count
            }
            justifications << sizes.max()!
        }

        return rows.map { columns -> String in
            var justColumns = ""
            for (index, column) in columns.enumerated() {
                let max = justifications[index]
                if max == 0 { continue }
                justColumns << column.ljust(max + column.count - column.noANSI.count)
                if index == columns.count - 3 {
                    justColumns << (column.count == 0 ? "  " : ", ")
                } else if index == columns.count - 2 {
                    justColumns << "    "
                }
            }
            return justColumns
        }
    }
}
