public enum Arg : CustomStringConvertible {
    /// A positional argument
    case argument(String)

    /// A boolean like option, `--version`, `--help`, `--no-clean`.
    case option(String)

    /// A flag
    case flag(String, Set<Character>)

    public var description:String {
        switch self {
        case .argument(let value):
            return value
        case .option(let key):
            return "--\(key)"
        case .flag(let string, _):
            return "-\(string)"
        }
    }

    var type:String {
        switch self {
        case .argument:
            return "argument"
        case .option:
            return "option"
        case .flag:
            return "flag"
        }
    }
}


public struct ArgumentParserError : Error, Equatable, CustomStringConvertible {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}


public func ==(lhs: ArgumentParserError, rhs: ArgumentParserError) -> Bool {
    return lhs.description == rhs.description
}

public final class ArgumentParser : NSObject, ArgumentConvertible {
    public var rawArguments: [String] = []

    fileprivate var _arguments: [Arg] = []

    public typealias Option = String
    public typealias Flag = Character

    /// Initialises the ArgumentParser with an array of arguments
    public init(arguments: [String] = []) {
        super.init()
        self.setupRawArguments(arguments)
    }

    public init(parser: ArgumentParser, shift: Bool = false) {
        super.init()
        rawArguments = parser.rawArguments
        _arguments = parser._arguments
    }

    private func arg(for argument: String) -> [Arg] {
        if argument.first == "-" {
            let flags = argument[argument.index(after: argument.startIndex)..<argument.endIndex]

            if flags.first == "-" {
                if let e = flags.firstIndex(of: "=") {
                    let option = flags[flags.index(after: flags.startIndex)..<e]
                    let arg = flags[flags.index(after: e)..<flags.endIndex]
                    return [.option(String(option)), .argument(String(arg))]
                } else {
                    let option = flags[flags.index(after: flags.startIndex)..<flags.endIndex]
                    return [.option(String(option))]
                }
            } else if flags.starts(with: "NS") {
                return [.option(String(flags))]
            } else {
                return [.flag(String(flags), Set(flags))]
            }
        } else {
            return [.argument(argument)]
        }
    }

    public func setupRawArguments(_ rawArguments: [String]) {
        self.rawArguments = rawArguments
        var args = [Arg]()
        rawArguments.forEach { argument in
            args.append(contentsOf: self.arg(for: argument))
        }
        self._arguments = args
    }

    public var rawDescription: String {
        return rawArguments.map { $0.contains(" ") ? $0.quoted : $0 }.joined(separator: " ")
    }

    public override var description: String {
        return _arguments.map { $0.description.quoted }.joined(separator: " ")
    }

    public var isEmpty: Bool {
        return _arguments.isEmpty
    }

    public var remainder: [String] {
        return _arguments.map { $0.description }
    }

    public var remainderArgs: [String] {
        var args = [String]()
        for argument in _arguments {
            switch argument {
            case .argument(let value):
                args.append(value.quoted)
            default:
                return args
            }
        }
        return args
    }

    public func append(argument: String) {
        self.append(arguments: [argument])
    }

    public func append(arguments: [String]) {
        let args = arguments.flatMap { self.arg(for: $0) }
        self._arguments.append(contentsOf: args)
    }

    public func unshift(argument: String) {
        self.unshift(arguments: [argument])
    }

    public func unshift(arguments: [String]) {
        let args = arguments.flatMap { self.arg(for: $0) }
        self._arguments.insert(contentsOf: args, at: 0)
    }

    /// Returns the first positional argument in the remaining arguments.
    public func argument(shift: Bool = true) -> String? {
        for (index, argument) in _arguments.enumerated() {
            switch argument {
            case .argument(let value):
                if shift {
                    _arguments.remove(at: index)
                }
                return value
            default:
                return nil
            }
        }

        return nil
    }

    /// Returns the first count positional argument in the remaining arguments.
    public func arguments(count: Int, shift: Bool = true) -> [String] {
        var removed = [String]()
        for (index, argument) in _arguments.enumerated() {
            if removed.count == count { return removed }
            switch argument {
            case .argument(let value):
                if shift {
                    _arguments.remove(at: index - removed.count)
                }
                removed.append(value)
            default:
                continue
            }
        }
        return removed
    }

    /// Returns the value for an option (--name Kyle, --name=Kyle)
    public func option(for name: Option, shift: Bool = true) throws -> String? {
        return try options(for: name)?.first
    }

    /// Returns the value for an option (--name Kyle, --name=Kyle)
    public func options(for name: Option, shift: Bool = true) throws -> [String]? {
        var index = 0
        var result = [String]()
        while index < _arguments.count {
            switch _arguments[index] {
            case .option(let key):
                if key == name {
                    _arguments.remove(at: index)
                    if _arguments.count > index {
                        switch _arguments[index] {
                        case .argument(let value):
                            result.append(value)
                            _arguments.remove(at: index)
                        default:
                            result.append("")
                            index += 1
                        }
                    }
                } else {
                    index += 1
                }
            default:
                index += 1
            }
        }
        if result.count > 0 {
            return result
        }
        let envName = "MBOX_\(name.uppercased().replacingOccurrences(of: "-", with: "_"))"
        if let v = ProcessInfo.processInfo.environment[envName] {
            return [v]
        }
        return nil
    }

    /// Returns whether an option was specified in the arguments
    public func hasOption(_ name: Option, shift: Bool = true) -> Bool {
        var index = 0
        for argument in _arguments {
            switch argument {
            case .option(let option):
                if option == name {
                    if shift {
                        _arguments.remove(at: index)
                    }
                    return true
                }
            default:
                break
            }

            index += 1
        }
        let envName = "MBOX_\(name.uppercased().replacingOccurrences(of: "-", with: "_"))"
        return ProcessInfo.processInfo.environment.has(key: envName)
    }

    /// Returns whether a flag was specified in the arguments
    public func hasFlag(_ name: Flag, shift: Bool = true) -> Bool {
        var index = 0
        for argument in _arguments {
            switch argument {
            case .flag(let string, let option):
                var options = option
                if options.contains(name) {
                    if shift {
                        options.remove(name)
                        _arguments.remove(at: index)

                        if !options.isEmpty {
                            _arguments.insert(.flag(string, options), at: index)
                        }
                    }
                    return true
                }
            default:
                break
            }

            index += 1
        }

        return false
    }

    /// Returns the value for a flag (-n Kyle)
    public func flag(for name: Flag, shift: Bool = true) throws -> String? {
        return try flags(for: name)?.first
    }

    /// Returns the value for a flag (-n Kyle)
    public func flags(for name: Flag, count: Int = 1, shift: Bool = true) throws -> [String]? {
        var index = 0
        var hasFlag = false

        for argument in _arguments {
            switch argument {
            case .flag(_, let flags):
                if flags.contains(name) {
                    hasFlag = true
                    break
                }
                fallthrough
            default:
                index += 1
            }

            if hasFlag {
                break
            }
        }

        if hasFlag {
            _arguments.remove(at: index)

            return try (0..<count).map { i in
                if _arguments.count > index {
                    let argument = _arguments.remove(at: index)
                    switch argument {
                    case .argument(let value):
                        return value
                    default:
                        throw ArgumentParserError("Unexpected \(argument.type) `\(argument)` as a value for `-\(name)`")
                    }
                }

                throw ArgumentError.missingValue("-\(name)")
            }
        }

        return nil
    }

    /// Returns the value for an option (--name Kyle, --name=Kyle) or flag (-n Kyle)
    public func value(for option: Option, or flag: Flag?, shift: Bool = true) throws -> String? {
        if let values = try values(for: option, or: flag) {
            return values.first ?? ""
        }
        return nil
    }

    /// Returns the values for an option (--name Kyle, --name=Kyle) or flag (-n Kyle)
    public func values(for option: Option, or flag: Flag?, shift: Bool = true) throws -> [String]? {
        if let value = try options(for: option) {
            return value
        } else if let flag = flag, let value = try flags(for: flag) {
            return value
        }

        return nil
    }

    public func last() -> Arg? {
        return self._arguments.last
    }
}
