import Foundation
import SwiftData

@Model
final class Event: Identifiable {
    var id: UUID
    var title: String
    var date: Date
    var location: String?
    var notes: String?
    var isCompleted: Bool
    
    init(title: String, date: Date, location: String? = nil, notes: String? = nil, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.location = location
        self.notes = notes
        self.isCompleted = false
    }
} 