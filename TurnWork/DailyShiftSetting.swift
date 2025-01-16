import SwiftUI

struct DailyShiftSetting: Identifiable, Codable {
    let id: UUID
    var dayNumber: Int
    var selectedShiftId: UUID?
    var customStartTime: Date?
    var customEndTime: Date?
    var customColor: Color?
    
    init(id: UUID = UUID(), dayNumber: Int, selectedShiftId: UUID? = nil,
         customStartTime: Date? = nil, customEndTime: Date? = nil, customColor: Color? = nil) {
        self.id = id
        self.dayNumber = dayNumber
        self.selectedShiftId = selectedShiftId
        self.customStartTime = customStartTime
        self.customEndTime = customEndTime
        self.customColor = customColor
    }
    
    enum CodingKeys: String, CodingKey {
        case id, dayNumber, selectedShiftId, customStartTime, customEndTime, customColor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dayNumber = try container.decode(Int.self, forKey: .dayNumber)
        selectedShiftId = try container.decodeIfPresent(UUID.self, forKey: .selectedShiftId)
        customStartTime = try container.decodeIfPresent(Date.self, forKey: .customStartTime)
        customEndTime = try container.decodeIfPresent(Date.self, forKey: .customEndTime)
        if let colorComponents = try container.decodeIfPresent([Double].self, forKey: .customColor) {
            customColor = Color(.sRGB,
                              red: colorComponents[0],
                              green: colorComponents[1],
                              blue: colorComponents[2],
                              opacity: colorComponents[3])
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dayNumber, forKey: .dayNumber)
        try container.encodeIfPresent(selectedShiftId, forKey: .selectedShiftId)
        try container.encodeIfPresent(customStartTime, forKey: .customStartTime)
        try container.encodeIfPresent(customEndTime, forKey: .customEndTime)
        if let color = customColor {
            let uiColor = UIColor(color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            try container.encode([Double(red), Double(green), Double(blue), Double(alpha)],
                               forKey: .customColor)
        }
    }
} 