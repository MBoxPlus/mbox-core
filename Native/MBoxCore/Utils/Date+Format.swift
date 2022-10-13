//
//  Date+Format.swift
//  MBoxCore
//
//  Created by Whirlwind on 2022/8/24.
//  Copyright © 2022 bytedance. All rights reserved.
//

import Foundation

extension Date {
    /// Create date object from custom string.
    ///
    ///     let date = Date(string: "20170112164800", format: "yyyyMMddHHmmss") // "Jan 12, 2017, 4:48 PM"
    ///
    /// - Parameter string: The date string
    /// - Parameter format: The format string
    public init?(string: String, format: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = format
        guard let date = dateFormatter.date(from: string) else { return nil }
        self = date
    }
}
