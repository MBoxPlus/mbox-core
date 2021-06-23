
public protocol ArgumentConvertible : CustomStringConvertible {
    /// Initialise the type with an ArgumentParser
    init(parser: ArgumentParser, shift: Bool) throws
}

extension ArgumentConvertible {
    init(string: String, shift: Bool = true) throws {
        try self.init(parser: ArgumentParser(arguments: [string]), shift: shift)
    }
}

extension String : ArgumentConvertible {
    public init(parser: ArgumentParser, shift: Bool = true) throws {
        if let value = parser.argument(shift: shift) {
            self.init(value)
        } else {
            throw ArgumentError.missingValue(nil)
        }
    }
}

extension Int : ArgumentConvertible {
    public init(parser: ArgumentParser, shift: Bool = true) throws {
        if let value = parser.argument(shift: shift) {
            if let value = Int(value) {
                self.init(value)
            } else {
                throw ArgumentError.invalidType(value: value, type: "number", argument: nil)
            }
        } else {
            throw ArgumentError.missingValue(nil)
        }
    }
}

extension Float : ArgumentConvertible {
    public init(parser: ArgumentParser, shift: Bool = true) throws {
        if let value = parser.argument(shift: shift) {
            if let value = Float(value) {
                self.init(value)
            } else {
                throw ArgumentError.invalidType(value: value, type: "number", argument: nil)
            }
        } else {
            throw ArgumentError.missingValue(nil)
        }
    }
}

extension Double : ArgumentConvertible {
    public init(parser: ArgumentParser, shift: Bool = true) throws {
        if let value = parser.argument(shift: shift) {
            if let value = Double(value) {
                self.init(value)
            } else {
                throw ArgumentError.invalidType(value: value, type: "number", argument: nil)
            }
        } else {
            throw ArgumentError.missingValue(nil)
        }
    }
}

extension Array: ArgumentConvertible where Element : ArgumentConvertible {
    public init(parser: ArgumentParser, shift: Bool = true) throws {
        var temp = [Element]()

        while true {
            do {
                temp.append(try Element(parser: parser, shift: shift))
            } catch ArgumentError.missingValue {
                break
            } catch {
                throw error
            }
        }

        self.init(temp)
    }
}
