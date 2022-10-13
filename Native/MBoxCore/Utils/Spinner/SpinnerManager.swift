//
//  SpinnerManager.swift
//  MBoxCore
//
//  Created by 詹迟晶 on 2021/11/4.
//  Copyright © 2021 bytedance. All rights reserved.
//
import Foundation
import Dispatch
import Signals

public final class SpinnerManager {

    public static var shared = SpinnerManager(terminal: UI.terminal!)

    var queue: DispatchQueue
    let group = DispatchGroup()

    var speed: Double = 0

    var spinners: [Spinner] = []
    private var renderedSpinners: [Spinner] = []
    let terminal: Terminal

    private(set) var running: Bool = false

    public init(terminal: Terminal) {
        self.terminal = terminal
        self.queue = DispatchQueue(label: "mbox.SpinnerManager")

//        Signals.trap(signal: .int) { _ in
//            print("\u{001B}[?25h", terminator: "")
//            //            exit(0)
//        }
    }

    @discardableResult
    func updateRuning() -> Bool {
        self.running = self.spinners.contains {
            $0.running
        }
        return self.running
    }

    private func start() {
        if self.running { return }
        if !self.updateRuning() { return }
        group.enter()
        self.hideCursor()
        DispatchQueue.global().async { [weak self] in
            guard let `self` = self else { return }
            while true {
                self.queue.sync {
                    self.renderSpinners()
                    if !self.updateRuning() {
                        self.spinners.removeAll()
                        self.renderedSpinners.removeAll()
                        self.terminal.enter()
                        self.group.leave()
                    }
                }
                if !self.running {
                    break
                }
                self.sleep(seconds: self.speed)
            }
        }
    }

    public func wait() {
        group.wait()
        self.unhideCursor()
    }

    public func addSpinner(_ spinner: Spinner) {
        spinner.manager = self
        self.queue.safeSync {
            self.spinners.append(spinner)
            spinner.start()
            self.renderSpinners()
            self.speed = self.spinners.min { $0.speed < $1.speed }!.speed
            self.start()
        }
    }

    func updateSpinner(_ spinner: Spinner) {
        self.renderSpinners()
//
//        self.queue.safeSync {
//            if !self.running { return }
//            guard let index = self.renderedSpinners.firstIndex(where: { $0 === spinner }) else { return }
//            let delta = self.renderedSpinners.count - index - 1
//            terminal.moveCursor(deltaLine: -delta)
//            terminal.print(spinner.renderSpinner())
//            if delta > 0 {
//                terminal.moveCursor(deltaLine: delta)
//            }
//        }
    }

    func renderSpinners() {
        self.queue.safeSync {
            if !self.running { return }
            if self.renderedSpinners.count > 0 {
                terminal.moveCursor(deltaLine: -(self.renderedSpinners.count - 1))
            }
            for (index, spinner) in self.spinners.enumerated() {
                if index > 0 {
                    if index <= self.renderedSpinners.count - 1 {
                        terminal.moveCursor(deltaLine: 1)
                    } else {
                        terminal.enter()
                    }
                }
                terminal.print(spinner.renderSpinner())
            }
            self.renderedSpinners = self.spinners
        }
    }

    func sleep(seconds: Double) {
        usleep(useconds_t(seconds * 1_000_000))
    }

    func hideCursor() {
        terminal.print(AnsiCodes.hideCursor)
    }

    func unhideCursor() {
        terminal.print(AnsiCodes.showCursor)
    }

}
