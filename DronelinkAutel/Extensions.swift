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
        let value = self.localizeForLibrary(libraryBundle: DronelinkAutel.bundle)
        return value
    }
    
    func escapeQuotes(_ type: String = "'") -> String {
        return self.replacingOccurrences(of: type, with: "\\\(type)")
    }
}
