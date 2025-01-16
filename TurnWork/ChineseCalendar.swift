import Foundation

struct ChineseCalendar {
    static let shared = ChineseCalendar()
    private let calendar = Calendar(identifier: .chinese)
    private let solarCalendar = Calendar(identifier: .gregorian)
    private let formatter = DateFormatter()
    
    // 农历节日
    private let lunarFestivals: [String: String] = [
        "1-1": "春节",
        "1-15": "元宵",
        "5-5": "端午",
        "7-7": "七夕",
        "8-15": "中秋",
        "9-9": "重阳",
        "12-30": "除夕"
    ]
    
    // 公历节日
    private let solarFestivals: [String: String] = [
        "1-1": "元旦",
        "2-14": "情人",
        "3-8": "妇女",
        "5-1": "劳动",
        "6-1": "儿童",
        "10-1": "国庆",
        "12-25": "圣诞"
    ]
    
    private init() {
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
    }
    
    func getLunarDate(_ date: Date) -> String {
        let components = calendar.dateComponents([.day, .month], from: date)
        
        if let day = components.day {
            // 初一显示月份
            if day == 1 {
                formatter.dateFormat = "MMM"
                return formatter.string(from: date)
            }
            
            // 其他日期显示日
            return getLunarDay(day)
        }
        return ""
    }
    
    func getFestival(_ date: Date) -> String? {
        // 检查农历节日
        let lunarComponents = calendar.dateComponents([.month, .day], from: date)
        if let month = lunarComponents.month, let day = lunarComponents.day {
            let key = "\(month)-\(day)"
            if let festival = lunarFestivals[key] {
                return festival
            }
        }
        
        // 检查公历节日
        let solarComponents = solarCalendar.dateComponents([.month, .day], from: date)
        if let month = solarComponents.month, let day = solarComponents.day {
            let key = "\(month)-\(day)"
            if let festival = solarFestivals[key] {
                return festival
            }
        }
        
        return nil
    }
    
    private func getLunarDay(_ day: Int) -> String {
        let lunarDays = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        return day <= lunarDays.count ? lunarDays[day - 1] : ""
    }
} 