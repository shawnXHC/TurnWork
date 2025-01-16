import SwiftUI
import SwiftData

@Model
final class ShiftType: Identifiable {
    var id: UUID
    var name: String
    var color: Int
    var startTime: Date
    var endTime: Date
    var workHours: Double
    var restMinutes: Int?
    var notes: String?
    var order: Int
    
    // 反向关联
    @Relationship(deleteRule: .nullify, inverse: \ShiftCycle.shifts)
    var cycles: [ShiftCycle]?
    
    var displayColor: Color {
        Color(red: Double((color >> 16) & 0xFF) / 255.0,
              green: Double((color >> 8) & 0xFF) / 255.0,
              blue: Double(color & 0xFF) / 255.0)
    }
    
    init(name: String, color: Color = .blue, startTime: Date, endTime: Date, 
         workHours: Double? = nil, restMinutes: Int? = nil, notes: String? = nil, order: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.restMinutes = restMinutes
        self.notes = notes
        
        // 计算工作时长
        if let hours = workHours {
            self.workHours = hours
        } else {
            self.workHours = endTime.timeIntervalSince(startTime) / 3600
        }
        
        // 设置顺序
        if let order = order {
            self.order = order
        } else {
            // 默认使用时间戳作为顺序
            self.order = Int(Date().timeIntervalSince1970)
        }
        
        // 转换Color为RGB值
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.color = (Int(red * 255) << 16) |
                    (Int(green * 255) << 8) |
                    Int(blue * 255)
    }
}

// 创建一个可以被 SwiftData 存储的设置类
@Model
final class ShiftDailySetting {
    var id: UUID
    var dayNumber: Int
    var selectedShiftId: UUID?
    var customStartTime: Date?
    var customEndTime: Date?
    // 存储颜色的RGB值
    var colorRed: Double?
    var colorGreen: Double?
    var colorBlue: Double?
    var colorAlpha: Double?
    
    var customColor: Color? {
        get {
            guard let red = colorRed,
                  let green = colorGreen,
                  let blue = colorBlue,
                  let alpha = colorAlpha else {
                return nil
            }
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
        }
        set {
            if let color = newValue {
                let uiColor = UIColor(color)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                
                colorRed = Double(red)
                colorGreen = Double(green)
                colorBlue = Double(blue)
                colorAlpha = Double(alpha)
            } else {
                colorRed = nil
                colorGreen = nil
                colorBlue = nil
                colorAlpha = nil
            }
        }
    }
    
    init(id: UUID = UUID(), dayNumber: Int, selectedShiftId: UUID? = nil,
         customStartTime: Date? = nil, customEndTime: Date? = nil, customColor: Color? = nil) {
        self.id = id
        self.dayNumber = dayNumber
        self.selectedShiftId = selectedShiftId
        self.customStartTime = customStartTime
        self.customEndTime = customEndTime
        self.customColor = customColor
    }
}

@Model
final class ShiftCycle: Identifiable {
    var id: UUID
    var name: String
    var days: Int
    @Relationship(deleteRule: .cascade) var shifts: [ShiftType]
    var startDate: Date
    var isActive: Bool
    var members: [String]?
    var notes: String?
    var shiftOrder: [Int]
    @Relationship(deleteRule: .cascade) var dailySettings: [ShiftDailySetting]?
    
    init(name: String, days: Int, shifts: [ShiftType], shiftOrder: [Int], startDate: Date, 
         isActive: Bool = false, members: [String]? = nil, notes: String? = nil,
         dailySettings: [ShiftDailySetting]? = nil) {
        self.id = UUID()
        self.name = name
        self.days = days
        self.shifts = shifts
        self.shiftOrder = shiftOrder
        self.startDate = startDate
        self.isActive = isActive
        self.members = members
        self.notes = notes
        self.dailySettings = dailySettings
    }
    
    // 获取指定日期的班次
    func getShift(for date: Date) -> ShiftType? {
        guard !shifts.isEmpty, !shiftOrder.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: date).day ?? 0
        
        if daysSinceStart < 0 { return nil }
        
        let cyclePosition = daysSinceStart % days
        let shiftIndex = shiftOrder[cyclePosition]
        return shifts[safe: shiftIndex]
    }
    
    // 获取指定日期范围内的所有班次
    func getShifts(from startDate: Date, to endDate: Date) -> [(date: Date, shift: ShiftType)] {
        var result: [(Date, ShiftType)] = []
        let calendar = Calendar.current
        var currentDate = startDate
        
        while currentDate <= endDate {
            if let shift = getShift(for: currentDate) {
                result.append((currentDate, shift))
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return result
    }
    
    // 计算工作统计
    func calculateStatistics(from startDate: Date, to endDate: Date) -> ShiftStatistics {
        let shifts = getShifts(from: startDate, to: endDate)
        var totalHours = 0.0
        var shiftCounts: [String: Int] = [:]
        
        for (_, shift) in shifts {
            totalHours += shift.workHours
            shiftCounts[shift.name, default: 0] += 1
        }
        
        return ShiftStatistics(
            totalDays: shifts.count,
            totalHours: totalHours,
            shiftCounts: shiftCounts
        )
    }
}

// 辅助类型和扩展
struct ShiftStatistics {
    var totalDays: Int
    var totalHours: Double
    var shiftCounts: [String: Int]
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
} 