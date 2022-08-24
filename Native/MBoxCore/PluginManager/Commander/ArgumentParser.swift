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

    public var remainderRawArgs: [String] {
        var args = [String]()
        var rawArgs = self.rawArguments
        let remainder = self.remainder
        for item in remainder {
            for (index, raw) in rawArgs.enumerated() {
                if raw.hasPrefix(item) {
                    rawArgs.removeFirst(index+1)
                    args.append(raw)
                    break
                }
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

    func eachArgument(block: (_ arg: String, _ shift: inout Bool) -> Bool) {
        var ids = [Int]()
        for (index, argument) in _arguments.enumerated() {
            var stop = false
            switch argument {
            case .argument(let value):
                var shift = false
                stop = block(value, &shift)
                if shift {
                    ids.append(index)
                }
            default:
                stop = true
                break
            }
            if stop {
                break
            }
        }
        if !ids.isEmpty {
            _arguments.remove(at: ids)
        }
    }

    private func findOption(name: String, block: (_ option: String, _ value: String?, _ shift: inout Bool, _ shiftValue: inout Bool) -> Bool) {
        var ids = [Int]()
        for (index, argument) in _arguments.enumerated() {
            var stop = false
            switch argument {
            case .option(let key):
                guard key == name else { continue }
                var value: String? = nil
                if _arguments.count > index + 1 {
                    switch _arguments[index + 1] {
                    case .argument(let v):
                        value = v
                    default: break
                    }
                }
                var shift = false
                var shiftValue = false
                stop = block(key, value, &shift, &shiftValue)
                if shift {
                    ids.append(index)
                    if value != nil, shiftValue {
                        ids.append(index + 1)
                    }
                }
            default:
                continue
            }
            if stop {
                break
            }
        }
        if !ids.isEmpty {
            _arguments.remove(at: ids)
        }
    }

    /// Returns the first positional argument in the remaining arguments.
    public func argument(shift: Bool = true) -> String? {
        var result: String? = nil
        self.eachArgument { (arg: String, shiftArg: inout Bool) in
            shiftArg = shift
            result = arg
            return true
        }
        return result
    }

    /// Returns the first count positional argument in the remaining arguments.
    public func arguments(count: Int, shift: Bool = true) -> [String] {
        var result = [String]()
        self.eachArgument { (arg: String, shiftArg: inout Bool) in
            if result.count == count { return true }
            shiftArg = shift
            result.append(arg)
            return false
        }
        return result
    }

    /// Returns the value for an option (--name Kyle, --name=Kyle)
    public func option(for name: Option, shift: Bool = true) throws -> String? {
        var result: String? = nil
        self.findOption(name: name) { (option: String, value: String?, shiftKey: inout Bool, shiftValue: inout Bool) in
            result = value
            shiftKey = shift
            shiftValue = shift
            return true
        }
        if let result = result { return result }
        if let v = self.fetchEnvironmentVariable(name, shift: shift) {
            return v
        }
        return nil
    }

    /// Returns the values for an option (--name Kyle, --name=Kyle)
    public func options(for name: Option, shift: Bool = true) throws -> [String]? {
        var result = [String]()
        self.findOption(name: name) { (option: String, value: String?, shiftKey: inout Bool, shiftValue: inout Bool) in
            guard let value = value else {
                return false
            }
            shiftKey = shift
            shiftValue = shift
            result.append(value)
            return false
        }
        if result.count > 0 {
            return result
        }
        if let v = self.fetchEnvironmentVariable(name, shift: shift) {
            return [v]
        }
        if let v = self.fetchEnvironmentVariables(name + "s", shift: shift) {
            return v
        }
        return nil
    }

    /// Returns whether an option was specified in the arguments
    public func hasOption(_ name: Option, shift: Bool = true) -> Bool {
        var result: Bool? = nil
        self.findOption(name: name) { (option: String, value: String?, shiftKey: inout Bool, shiftValue: inout Bool) in
            shiftKey = shift
            if let value = value, let b = value.bool {
                result = b
                shiftValue = shift
            } else {
                result = true
            }
            return true
        }
        if let result = result { return result }
        guard let value = self.fetchEnvironmentVariable(name, shift: false) else {
            return false
        }
        guard let b = value.bool else { return false }
        self.removeEnvironmentVariable(name)
        return b
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

    private func fetchEnvironmentVariable(_ name: String, shift: Bool) -> String? {
        let envName = "MBOX_\(name.uppercased().replacingOccurrences(of: "-", with: "_"))"
        return ProcessInfo.processInfo.environment(name: envName, remove: shift)
    }

    private func fetchEnvironmentVariables(_ name: String, shift: Bool) -> [String]? {
        let envName = "MBOX_\(name.uppercased().replacingOccurrences(of: "-", with: "_"))"
        if let v = ProcessInfo.processInfo.environment(name: envName, remove: shift) {
            return v.split(separator: ",").map { String($0) }
        }
        return nil
    }

    private func removeEnvironmentVariable(_ name: String) {
        let envName = "MBOX_\(name.uppercased().replacingOccurrences(of: "-", with: "_"))"
        ProcessInfo.processInfo.removeEnvironment(name: envName)
    }
}
