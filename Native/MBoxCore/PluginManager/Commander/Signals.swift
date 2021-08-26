//
//  Signals.swift
//  MBoxCore
//
//  Created by Whirlwind on 2020/6/9.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation
import Signals

public struct SignalType: OptionSet {
    public let rawValue: Int

    public static let Cancel = SignalType(rawValue: 1 << 0)
    public static let Crash = SignalType(rawValue: 1 << 1)

    public static let all: SignalType = [.Cancel, .Crash]

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public func trapSignal(_ type: SignalType, action: @escaping @convention(c)(Int32) -> Void) {
    for signal in signals(for: type) {
        let v = signal.valueOf
        var actions = signalActions[v] ?? []
        if actions.isEmpty {
            Signals.trap(signal: signal) { signal in
                performSignal(signal)
            }
        }
        actions.append(action)
        signalActions[v] = actions
    }
}

public func ignoreSignal(_ signal: Int32) {
    Signals.ignore(signal: Signals.Signal.user(Int(signal)))
}

public var exitSignal: Int32?

private var signalActions = [Int32: [@convention(c)(Int32) -> Void]]()
public func performSignal(_ signal: Int32) {
    guard exitSignal == nil,
          let actions = signalActions[signal] else {
        return
    }
    exitSignal = signal
    DispatchQueue.global().async {
        while !UI.runningCMDs.isEmpty {
            sleep(1)
        }
        for action in actions.reversed() {
            action(signal)
        }
    }
}

public func signals(for type: SignalType) -> [Signals.Signal] {
    var v = [Signals.Signal]()
    if type.contains(.Crash) {
        v.append(contentsOf: [.user(Int(SIGSEGV)), .user(Int(SIGBUS)), .user(Int(SIGFPE)), .user(Int(SIGILL))])
    }
    if type.contains(.Cancel) {
        v.append(contentsOf: [.quit, .pipe, .hup, .int, .abrt, .kill, .term])
    }
    return v
}
