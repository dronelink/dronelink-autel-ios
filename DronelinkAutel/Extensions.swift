//
//  Extensions.swift
//  DronelinkAutel
//
//  Created by Jim McAndrew on 1/15/22.
//  Copyright © 2022 Dronelink. All rights reserved.
//
import Foundation
import DronelinkCore

extension String {
    private static let LocalizationMissing = "MISSING STRING LOCALIZATION"
    
    var localized: String {
        let value = DronelinkAutel.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
        //assert(value != String.LocalizationMissing, "String localization missing: \(self)")
        return value
    }
    
    func escapeQuotes(_ type: String = "'") -> String {
        return self.replacingOccurrences(of: type, with: "\\\(type)")
    }
}
