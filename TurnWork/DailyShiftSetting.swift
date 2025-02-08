import SwiftUI

struct DailyShiftSetting: Identifiable, Codable {
    let id: UUID
    var dayNumber: Int
    var selectedShiftId: UUID?
    
    init(id: UUID = UUID(), dayNumber: Int, selectedShiftId: UUID? = nil) {
        self.id = id
        self.dayNumber = dayNumber
        self.selectedShiftId = selectedShiftId
    }
    
    enum CodingKeys: String, CodingKey {
        case id, dayNumber, selectedShiftId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dayNumber = try container.decode(Int.self, forKey: .dayNumber)
        selectedShiftId = try container.decodeIfPresent(UUID.self, forKey: .selectedShiftId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dayNumber, forKey: .dayNumber)
        try container.encodeIfPresent(selectedShiftId, forKey: .selectedShiftId)
    }
} 