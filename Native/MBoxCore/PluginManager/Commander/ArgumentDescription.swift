public enum ArgumentType {
    case argument
    case option
    case flag
}

public protocol ArgumentDescriptor {
    /// The arguments name
    var name: String { get }
    var type: ArgumentType { get }
    /// The arguments description
    var description: String? { get }
    var nameDescription: String { get }
}

public class Argument: ArgumentDescriptor {

    public let name: String
    public let description: String?
    public var values: [String]
    public var type: ArgumentType { return .argument }
    public let required: Bool
    public let plural: Bool

    public init(_ name: String, description: String? = nil, values: [String] = [], required: Bool = false, plural: Bool = false) {
        self.name = name
        self.values = values
        if values.isEmpty {
            self.description = description
        } else {
            let valueDesc = "Avaliable: \(values.joined(separator: "/"))"
            if let desc = description {
                self.description = "\(desc) \(valueDesc)"
            } else {
                self.description = valueDesc
            }
        }
        self.required = required
        self.plural = plural
    }

    public func parse<T: ArgumentConvertible>(_ parser: ArgumentParser, shift: Bool = true) throws -> T {
        do {
            let value = try T(parser: parser, shift: shift)
            return value
        } catch ArgumentError.missingValue {
            throw ArgumentError.missingArgument(name.uppercased())
        } catch {
            throw error
        }
    }

    public var nameDescription: String {
        return name
    }

}


public class Option: ArgumentDescriptor {
    public let name: String
    public let flag: Character?
    public let _description: String?
    public var values: [String] = []
    public var valuesBlock: (() -> [String])?
    public var type: ArgumentType { return .option }

    public init(_ name: String, flag: Character? = nil, description: String? = nil, values: [String] = [], valuesBlock: (()->[String])? = nil) {
        self.name = name
        self.flag = flag
        self.values = values
        self.valuesBlock = valuesBlock
        self._description = description
    }

    public var description: String? {
        var desc = [self._description ?? ""]
        let values = valuesBlock?() ?? self.values
        if !values.isEmpty {
            let valueDesc = "Avaliable: \(values.joined(separator: "/"))"
            desc.append(valueDesc)
        }
        return desc.joined(separator: " ")
    }

    public func parse<T: ArgumentConvertible>(_ parser: ArgumentParser, shift: Bool = true) throws -> T? {
        guard let shifted = try parser.value(for: name, or: flag, shift: shift) else { return nil }
        return try T(string: shifted)
    }

    public func parse<T: ArgumentConvertible>(_ parser: ArgumentParser, default: T, shift: Bool = true) throws -> T {
        guard let shifted = try parser.value(for: name, or: flag, shift: shift) else { return `default` }
        if shifted == "" {
            return `default`
        }
        return try T(string: shifted)
    }

    public func parseMany<T: ArgumentConvertible>(_ parser: ArgumentParser, shift: Bool = true) throws -> [T]? {
        guard let shifted = try parser.values(for: name, or: flag, shift: shift) else { return nil }
        return try shifted.map { try T(string: $0) }
    }

    public var nameDescription: String {
        var desc = [String]()
        if let flag = flag {
            desc << "-\(flag),"
        } else {
            desc << "   "
        }
        desc << "--\(name)"
        return desc.joined(separator: " ")
    }
}

public class Flag : Option {

    public let disabledName: String
    public let disabledFlag: Character?
    public override var type: ArgumentType { return .flag }

    public init(_ name: String, flag: Character? = nil, disabledName: String? = nil, disabledFlag: Character? = nil, description: String? = nil) {
        self.disabledName = disabledName ?? "no-\(name)"
        self.disabledFlag = disabledFlag
        super.init(name, flag: flag, description: description)
    }

    public func parse(_ parser: ArgumentParser, shift: Bool = true) throws -> Bool? {
        if parser.hasOption(disabledName, shift: shift) {
            return false
        }

        if parser.hasOption(name, shift: shift) {
            return true
        }

        if let flag = flag {
            if parser.hasFlag(flag, shift: shift) {
                return true
            }
        }
        if let disabledFlag = disabledFlag {
            if parser.hasFlag(disabledFlag, shift: shift) {
                return false
            }
        }

        return nil
    }

    public func parse(_ parser: ArgumentParser, default: Bool, shift: Bool = true) throws -> Bool {
        return try parse(parser, shift: shift) ?? `default`
    }
}
