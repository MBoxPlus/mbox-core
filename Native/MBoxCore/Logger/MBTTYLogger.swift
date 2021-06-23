//
//  MBTTYLogger.swift
//  MBoxCore
//
//  Created by Whirlwind on 2019/7/6.
//  Copyright © 2019 bytedance. All rights reserved.
//

import CocoaLumberjack

public class MBTTYLogger: DDTTYLogger {
    public override func std(for logMessage: DDLogMessage!) -> Int32 {
        if (logMessage.context & MBLoggerPipe.STDERR.rawValue) > 0 {
            return STDERR_FILENO
        }
        return STDOUT_FILENO
    }
}
