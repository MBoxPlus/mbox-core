//
//  Terminal.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/7/6.
//  Copyright © 2019 bytedance. All rights reserved.
//

extension FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

public class Terminal {
    public init(in: Int32 = STDIN_FILENO, out: Int32 = STDOUT_FILENO, error: Int32 = STDERR_FILENO) {
        self.IN_FILENO = `in`
        self.OUT_FILENO = out
        self.ERROR_FILENO = error
    }

    public let IN_FILENO: Int32
    public let OUT_FILENO: Int32
    public let ERROR_FILENO: Int32

    var queue: DispatchQueue = .init(label: "mbox.ttylogger")

    public var isTTY: Bool {
        return isatty(IN_FILENO) == 1
    }

    // MARK: Raw Mode
    var originalTermios: termios?
    var isRawMode: Bool = false
    public func enableRawMode() throws {
        try self.queue.safeSync {
            if self.isRawMode { return }
            if !isTTY {
                throw LinenoiseError.notATTY
            }

            self.originalTermios = termios()
            if tcgetattr(IN_FILENO, &originalTermios!) == -1 {
                throw LinenoiseError.generalError("Could not get term attributes")
            }
            var raw = originalTermios!

#if os(Linux) || os(FreeBSD)
            raw.c_iflag &= ~UInt32(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
            raw.c_oflag &= ~UInt32(OPOST)
            raw.c_cflag |= UInt32(CS8)
            raw.c_lflag &= ~UInt32(ECHO | ICANON | IEXTEN | ISIG)
#else
            raw.c_iflag &= ~UInt(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
            raw.c_oflag &= ~UInt(OPOST)
            raw.c_cflag |= UInt(CS8)
            raw.c_lflag &= ~UInt(ECHO | ICANON | IEXTEN | ISIG)
#endif

            // VMIN = 16
            raw.c_cc.16 = 1

            if tcsetattr(IN_FILENO, Int32(TCSAFLUSH), &raw) < 0 {
                throw LinenoiseError.generalError("Could not set raw mode")
            }
            self.isRawMode = true
        }
    }

    public func disabeRawMode() {
        self.queue.safeSync {
            if !self.isRawMode || self.originalTermios == nil {
                return
            }
            _ = tcsetattr(IN_FILENO, TCSAFLUSH, &originalTermios!)
            self.isRawMode = false
            self.originalTermios = nil
        }
    }

    public func withRawMode(body: () throws -> ()) throws {
        try self.enableRawMode()
        defer {
            self.disabeRawMode()
        }
        try body()
    }

    public func getNumCols() -> Int {
        var winSize = winsize()

        if ioctl(1, UInt(TIOCGWINSZ), &winSize) == -1 || winSize.ws_col == 0 {
            // Couldn't get number of columns with ioctl
            guard let start = self.getCursorPosition()?.column else {
                return 80
            }

            if !self.print(AnsiCodes.cursorForward(999)) {
                return 80
            }

            guard let cols = self.getCursorPosition()?.column else {
                return 80
            }

            // Restore original cursor position
            if !self.print(AnsiCodes.cursorForward(start)) {
                // Can't recover from this
            }

            return cols
        } else {
            return Int(winSize.ws_col)
        }
    }

    // MARK: - Cursor
    public func getCursorPosition() -> (row: Int, column: Int)? {
        return queue.safeSync {
            let text = AnsiCodes.cursorLocation
            if write(OUT_FILENO, text, text.count) == -1 {
                return nil
            }

            var buf = [UInt8]()
            while true {
                var input: UInt8 = 0
                let count = read(IN_FILENO, &input, 1)
                if count == 0 {
                    return nil
                }
                if input == 82 { // "R"
                    break
                }
                buf.append(input)
            }

            // Check the first characters are the escape code
            if buf[0] != 0x1B || buf[1] != 0x5B {
                return nil
            }

            let positionText = String(bytes: buf[2..<buf.count], encoding: .utf8)
            guard let data = positionText?.split(separator: ";").compactMap({ Int(String($0)) }) else {
                return nil
            }

            if data.count != 2 {
                return nil
            }

            return (row: data[0], column: data[1])
        }
    }

    public func moveCursor(dx: Int = 0, dy: Int = 0) {
        var command = ""
        if dx > 0 {
            command += AnsiCodes.cursorDown(dx)
        } else if dx < 0 {
            command += AnsiCodes.cursorUp(-dx)
        }
        if dy > 0 {
            command += AnsiCodes.cursorForward(dy)
        } else if dy < 0 {
            command += AnsiCodes.cursorBack(-dy)
        }
        if command.isEmpty { return }
        self.print(command)
    }

    public func moveCursor(deltaLine: Int) {
        var command = ""
        if deltaLine > 0 {
            command += AnsiCodes.cursorNextLine(deltaLine)
        } else if deltaLine < 0 {
            command += AnsiCodes.cursorPreviousLine(-deltaLine)
        } else {
            command += ControlCharacters.Return.description
        }
        if command.isEmpty { return }
        self.print(command)
        fflush(stdout)
    }

    public func enter() {
        self.print("\(ControlCharacters.Return.character)\(ControlCharacters.NextLine.character)")
    }

    @discardableResult
    public func print(_ char: Character, to: Int32? = nil) -> Bool {
        return self.print(String(char), to: to)
    }

    @discardableResult
    public func print(_ string: String, to: Int32? = nil) -> Bool {
        return queue.safeSync {
            var fh = FileHandle(fileDescriptor: to ?? OUT_FILENO)
            Swift.print(string, terminator: "", to: &fh)
            return true
        }
    }

    public func readCharacter() -> UInt8? {
        return queue.safeSync {
            var input: UInt8 = 0
            let count = read(IN_FILENO, &input, 1)

            if count == 0 {
                return nil
            }

            return input
        }
    }

}

var kTerminalLogFormatterKey: UInt8 = 0
extension Terminal: MBLogger {
    // MARK: - MBLogger
    var async: Bool {
        return false
    }

    var level: MBLogLevel {
        if MBProcess.shared.apiFormatter != .none {
            return .info
        }
        if MBProcess.shared.verbose {
            return .verbose
        }
        return .info
    }

    var logFormatter: MBLoggerFormat? {
        return associatedObject(base: self, key: &kTerminalLogFormatterKey) {
            return MBLoggerFormatter()
        }
    }

    func isSupport(pip: MBLoggerPipe) -> Bool {
        return pip.contains(.STDERR) || pip.contains(.STDOUT)
    }

    func logMessage(_ logMessage: MBLogMessage) {
        let message = logMessage.message
        var pip: Int32
        if logMessage.pip.contains(.STDOUT) {
            pip = STDOUT_FILENO
        } else if logMessage.pip.contains(.STDERR) {
            pip = STDERR_FILENO
        } else {
            return
        }
        print(message, to: pip)
    }

    func close() {
    }
}

extension Terminal {
    // MARK: - Colors

    enum ColorSupport {
        case standard
        case twoFiftySix
    }

    // Colour tables from https://jonasjacek.github.io/colors/
    // Format: (r, g, b)

    static let colors: [(Int, Int, Int)] = [
        // Standard
        (0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0), (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
        // High intensity
        (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
        // 256 color extended
        (0, 0, 0), (0, 0, 95), (0, 0, 135), (0, 0, 175), (0, 0, 215), (0, 0, 255), (0, 95, 0), (0, 95, 95),
        (0, 95, 135), (0, 95, 175), (0, 95, 215), (0, 95, 255), (0, 135, 0), (0, 135, 95), (0, 135, 135),
        (0, 135, 175), (0, 135, 215), (0, 135, 255), (0, 175, 0), (0, 175, 95), (0, 175, 135), (0, 175, 175),
        (0, 175, 215), (0, 175, 255), (0, 215, 0), (0, 215, 95), (0, 215, 135), (0, 215, 175), (0, 215, 215),
        (0, 215, 255), (0, 255, 0), (0, 255, 95), (0, 255, 135), (0, 255, 175), (0, 255, 215), (0, 255, 255),
        (95, 0, 0), (95, 0, 95), (95, 0, 135), (95, 0, 175), (95, 0, 215), (95, 0, 255), (95, 95, 0), (95, 95, 95),
        (95, 95, 135), (95, 95, 175), (95, 95, 215), (95, 95, 255), (95, 135, 0), (95, 135, 95), (95, 135, 135),
        (95, 135, 175), (95, 135, 215), (95, 135, 255), (95, 175, 0), (95, 175, 95), (95, 175, 135), (95, 175, 175),
        (95, 175, 215), (95, 175, 255), (95, 215, 0), (95, 215, 95), (95, 215, 135), (95, 215, 175), (95, 215, 215),
        (95, 215, 255), (95, 255, 0), (95, 255, 95), (95, 255, 135), (95, 255, 175), (95, 255, 215), (95, 255, 255),
        (135, 0, 0), (135, 0, 95), (135, 0, 135), (135, 0, 175), (135, 0, 215), (135, 0, 255), (135, 95, 0), (135, 95, 95),
        (135, 95, 135), (135, 95, 175), (135, 95, 215), (135, 95, 255), (135, 135, 0), (135, 135, 95), (135, 135, 135),
        (135, 135, 175), (135, 135, 215), (135, 135, 255), (135, 175, 0), (135, 175, 95), (135, 175, 135),
        (135, 175, 175), (135, 175, 215), (135, 175, 255), (135, 215, 0), (135, 215, 95), (135, 215, 135),
        (135, 215, 175), (135, 215, 215), (135, 215, 255), (135, 255, 0), (135, 255, 95), (135, 255, 135),
        (135, 255, 175), (135, 255, 215), (135, 255, 255), (175, 0, 0), (175, 0, 95), (175, 0, 135), (175, 0, 175),
        (175, 0, 215), (175, 0, 255), (175, 95, 0), (175, 95, 95), (175, 95, 135), (175, 95, 175), (175, 95, 215),
        (175, 95, 255), (175, 135, 0), (175, 135, 95), (175, 135, 135), (175, 135, 175), (175, 135, 215),
        (175, 135, 255), (175, 175, 0), (175, 175, 95), (175, 175, 135), (175, 175, 175), (175, 175, 215),
        (175, 175, 255), (175, 215, 0), (175, 215, 95), (175, 215, 135), (175, 215, 175), (175, 215, 215),
        (175, 215, 255), (175, 255, 0), (175, 255, 95), (175, 255, 135), (175, 255, 175), (175, 255, 215),
        (175, 255, 255), (215, 0, 0), (215, 0, 95), (215, 0, 135), (215, 0, 175), (215, 0, 215), (215, 0, 255),
        (215, 95, 0), (215, 95, 95), (215, 95, 135), (215, 95, 175), (215, 95, 215), (215, 95, 255), (215, 135, 0),
        (215, 135, 95), (215, 135, 135), (215, 135, 175), (215, 135, 215), (215, 135, 255), (215, 175, 0),
        (215, 175, 95), (215, 175, 135), (215, 175, 175), (215, 175, 215), (215, 175, 255), (215, 215, 0),
        (215, 215, 95), (215, 215, 135), (215, 215, 175), (215, 215, 215), (215, 215, 255), (215, 255, 0),
        (215, 255, 95), (215, 255, 135), (215, 255, 175), (215, 255, 215), (215, 255, 255), (255, 0, 0),
        (255, 0, 95), (255, 0, 135), (255, 0, 175), (255, 0, 215), (255, 0, 255), (255, 95, 0), (255, 95, 95),
        (255, 95, 135), (255, 95, 175), (255, 95, 215), (255, 95, 255), (255, 135, 0), (255, 135, 95),
        (255, 135, 135), (255, 135, 175), (255, 135, 215), (255, 135, 255), (255, 175, 0), (255, 175, 95),
        (255, 175, 135), (255, 175, 175), (255, 175, 215), (255, 175, 255), (255, 215, 0), (255, 215, 95),
        (255, 215, 135), (255, 215, 175), (255, 215, 215), (255, 215, 255), (255, 255, 0), (255, 255, 95),
        (255, 255, 135), (255, 255, 175), (255, 255, 215), (255, 255, 255), (8, 8, 8), (18, 18, 18),
        (28, 28, 28), (38, 38, 38), (48, 48, 48), (58, 58, 58), (68, 68, 68), (78, 78, 78), (88, 88, 88),
        (98, 98, 98), (108, 108, 108), (118, 118, 118), (128, 128, 128), (138, 138, 138), (148, 148, 148),
        (158, 158, 158), (168, 168, 168), (178, 178, 178), (188, 188, 188), (198, 198, 198), (208, 208, 208),
        (218, 218, 218), (228, 228, 228), (238, 238, 238)
    ]

    static func termColorSupport(termVar: String) -> ColorSupport {
        // A rather dumb way of detecting colour support

        if termVar.contains("256") {
            return .twoFiftySix
        }

        return .standard
    }

    static func closestColor(to targetColor: (Int, Int, Int), withColorSupport colorSupport: ColorSupport) -> Int {
        let colorTable: [(Int, Int, Int)]

        switch colorSupport {
        case .standard:
            colorTable = Array(colors[0..<8])
        case .twoFiftySix:
            colorTable = colors
        }

        let distances = colorTable.map {
            sqrt(pow(Double($0.0 - targetColor.0), 2) +
                 pow(Double($0.1 - targetColor.1), 2) +
                 pow(Double($0.2 - targetColor.2), 2))
        }

        var closest = Double.greatestFiniteMagnitude
        var closestIdx = 0

        for i in 0..<distances.count {
            if distances[i] < closest  {
                closest = distances[i]
                closestIdx = i
            }
        }

        return closestIdx
    }

}
