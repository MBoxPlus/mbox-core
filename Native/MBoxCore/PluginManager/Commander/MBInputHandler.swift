//
//  MBInputHandler.swift
//  MBoxCore
//
//  Created by Whirlwind on 2021/3/4.
//  Copyright © 2021 bytedance. All rights reserved.
//

import Foundation
import ObjCCommandLine
import Signals

public protocol MBInputHandlerDelegate: AnyObject {
    func userInput(_ data: Data)
}

open class MBInputHandler {
    public static let shared = MBInputHandler()

    lazy var delegates = NSPointerArray()
    open var inputHandle: FileHandle?

    init() {
        guard MBCMD.isCMDEnvironment else {
            return
        }
        inputHandle = FileHandle.standardInput
        NotificationCenter.default.addObserver(self, selector: #selector(getInput(_:)), name: .NSFileHandleDataAvailable, object: inputHandle)
        inputHandle?.waitForDataInBackgroundAndNotify()
    }

    @objc
    open func getInput(_ aNotification: Notification) {
        guard let handle = aNotification.object as? FileHandle else {
            return
        }
        if handle.readable {
            let data = handle.availableData
            for delegate in self.delegates.allObjects.reversed() {
                guard let delegate = delegate as? MBInputHandlerDelegate else {
                    continue
                }
                delegate.userInput(data)
            }
            checkSignals(data)
        }
        handle.waitForDataInBackgroundAndNotify()
    }

    func checkSignals(_ data: Data) {
        let bytes = data.bytes
        guard bytes.count == 1 else { return }
        let signal = Int32(bytes.first!)
        switch signal {
        case 3:
            performSignal(Signals.Signal.int.valueOf) // CTRL + C
        case 26:
            Signals.raise(signal: Signals.Signal.user(Int(SIGTSTP))) // CTRL + Z
        default: break
        }
    }

    open func addDelegate(_ delegate: MBInputHandlerDelegate) {
        self.delegates.addWeakObject(delegate)
    }

    open func removeDelegate(_ delegate: MBInputHandlerDelegate) {
        self.delegates.removeWeekObject(delegate)
    }
}
