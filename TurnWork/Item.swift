//
//  Item.swift
//  TurnWork
//
//  Created by seanxia on 2025/1/15.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
