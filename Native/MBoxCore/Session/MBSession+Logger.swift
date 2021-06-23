//
//  MBSession+Logger.swift
//  MBoxCore
//
//  Created by Whirlwind on 2018/8/30.
//  Copyright © 2018年 Bytedance. All rights reserved.
//

import Foundation

// MARK: section
extension MBSession {

    private static var _dateFormatter: DateFormatter?
    private static var dateFormatter: DateFormatter {
        if let formatter = _dateFormatter {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.init(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy'/'MM'/'dd' 'HH':'mm':'ss'.'SSS'"
        _dateFormatter = formatter
        return formatter
    }

    private static var _durationFormatter: DateComponentsFormatter?
    static var durationFormatter: DateComponentsFormatter {
        if let formatter = _durationFormatter {
            return formatter
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.second, .minute]
        formatter.unitsStyle = .full
        _durationFormatter = formatter
        return formatter
    }



}

//extension MBSession {
//
//    public func asyncSection(_ title: String? = nil,
//                        file: StaticString = #file,
//                        function: StaticString = #function,
//                        line: UInt = #line,
//                        block: @escaping (_ session: MBSession) throws -> Void {
//        if finishCallback != nil || wait {
//            dispatchGroup = DispatchGroup()
//        }
//        try section(title: title, file: file, function: function, line: line, block: block)
//        if wait || finishCallback != nil {
//            dispatchGroup?.wait()
//        }
//        if let finishCallback = finishCallback {
//            finishCallback(self)
//        }
//        dispatchGroup = nil
//    }
//
//    @discardableResult
//    private func newSection(_ title: String? = nil,
//                            file: StaticString = #file,
//                            function: StaticString = #function,
//                            line: UInt = #line,
//                            wait: Bool = false,
//                            block: @escaping (_ session: MBSession) throws -> Void,
//                            finishCallback: ((_ session: MBSession) -> Void)?) rethrows -> MBSession {
//        let session = MBSession()
//        UI.title = title
//
//        synchronized(self) { () -> Void in
//            UI.parentSession = self
//            self.subSessions.append(session)
//            if UI.isSubSession {
//                UI.mainTitle = self.mainTitle
//                UI.logger = self.logger
//                UI.indent = self.indent
//            }
//        }
//
//        dispatchGroup?.enter()
//
//        let threadName = Thread.current.isMainThread ? title : Thread.current.name
//        let workItem = DispatchWorkItem {
//            Thread.current.name = threadName
//            Thread.current.threadDictionary["Session"] = session
//            let startTime = Date()
//            if !UI.isSubSession {
//                UI.logger.log(info: "========= Start \(MBUI.dateFormatter.string(from: startTime)) =========")
//            }
//            self.postNotification(NTF.start, session: session)
//            try? UI.section(title: title, file: file, function: function, line: line, block: block, waitCallback: waitCallback)
//
//            let finishTime = Date()
//            UI.duration = finishTime.timeIntervalSince(startTime)
//            if !UI.isSubSession {
//                let duration = MBUI.durationFormatter.string(from: startTime, to: finishTime)!
//                UI.logger.log(info: "========= Finished (\(duration)) \(MBUI.dateFormatter.string(from: finishTime)) =========")
//            }
//            synchronized(self) { () -> Void in
//                self.status = UI.status && self.status
//                self.subSessions.removeAll(where: { $0 === session })
//            }
//            self.postNotification(NTF.finish, session: session)
//            self.dispatchGroup?.leave()
//            Thread.current.threadDictionary["Session"] = nil
//            if !UI.isSubSession && !ObjCShell.isCMDEnvironment {
//                NSUserNotification.delayDeliver()
//            }
//        }
//        UI.workItem = workItem
//        DispatchQueue.global().async(execute: workItem)
//        return session
//    }
//}
