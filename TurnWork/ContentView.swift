//
//  ContentView.swift
//  TurnWork
//
//  Created by seanxia on 2025/1/15.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @Query private var cycles: [ShiftCycle]
    @State private var selectedDate = Date()
    @State private var showingAddEvent = false
    @State private var selectedEvents: [Event] = []
    @State private var showingShiftSchedule = false
    
    private let calendar = Calendar.current
    private let weekDays = ["Mon", "Tue", "Wen", "Thu", "Fri", "Sat", "Sun"]
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    
    var activeCycle: ShiftCycle? {
        cycles.first(where: { $0.isActive })
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 日历部分
                ScrollView {
                    VStack(spacing: 20) {
                        // 月份选择器
                        MonthSelectorView(selectedDate: $selectedDate)
                        
                        // 星期标题
                        WeekdayHeaderView()
                        
                        // 日历网格
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 5) {
                            ForEach(daysInMonth(), id: \.self) { date in
                                if let date = date {
                                    DayCell(
                                        date: date,
                                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                        isToday: calendar.isDateInToday(date),
                                        events: eventsForDate(date),
                                        shift: getShiftForDate(date)
                                    )
                                    .onTapGesture {
                                        withAnimation {
                                            selectedDate = date
                                            selectedEvents = eventsForDate(date)
                                        }
                                    }
                                } else {
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fill)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 选中日期的事件列表
                        if !selectedEvents.isEmpty {
                            EventListView(events: selectedEvents)
                                .padding()
                        }
                    }
                }
                
                // 添加事件按钮
                Button(action: { showingAddEvent = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                        .shadow(radius: 2)
                }
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        ForEach(cycles) { cycle in
                            Button(action: {
                                activateCycle(cycle)
                            }) {
                                HStack {
                                    Text(cycle.name)
                                    if cycle.isActive {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: { showingShiftSchedule = true }) {
                            Label("排班设置", systemImage: "gear")
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 20))
                            Text(activeCycle?.name ?? "选择周期")
                                .font(.system(size: 15))
                        }
                        .foregroundColor(.purple)
                    }
                }
            
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView()
        }
        .sheet(isPresented: $showingShiftSchedule) {
            NavigationView {
                ShiftScheduleView()
            }
        }
        .onAppear {
            // 初始化选中日期的事件
            selectedEvents = eventsForDate(selectedDate)
        }
    }
    
    private func activateCycle(_ selectedCycle: ShiftCycle) {
        // 停用其他周期
        for cycle in cycles {
            cycle.isActive = (cycle.id == selectedCycle.id)
        }
        try? modelContext.save()
    }
    
    private func monthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func isDateInSelectedRange(_ date: Date) -> Bool {
        let selectedDates = getSelectedDateRange()
        return selectedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }
    
    private func getSelectedDateRange() -> [Date] {
        // 这里可以根据需要返回连续的日期范围
        [selectedDate]
    }
    
    private func daysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: selectedDate)!
        let firstDay = interval.start
        
        // 获取月初是星期几
        let weekday = calendar.component(.weekday, from: firstDay)
        let offsetDays = (weekday + 5) % 7 // 调整为周一开始
        
        var days: [Date?] = Array(repeating: nil, count: offsetDays)
        
        // 获取这个月的总天数
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)!.count
        
        // 添加这个月的所有日期
        for day in 1...daysInMonth {
            if let date = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))?.addingTimeInterval(TimeInterval((day - 1) * 24 * 60 * 60)) {
                days.append(date)
            }
        }
        
        // 补充末尾的空白天数，使总数为7的倍数
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func eventsForDate(_ date: Date) -> [Event] {
        events
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }
    
    private var todayEvents: [Event] {
        events.filter { calendar.isDate($0.date, inSameDayAs: Date()) }
    }
    
    private var upcomingEvents: [Event] {
        let now = Date()
        return events
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(3)
            .map { $0 }
    }
    
    private func getShiftForDate(_ date: Date) -> (shift: ShiftType?, color: Color?)? {
        guard let cycle = activeCycle else { return nil }
        
        let daysSinceStart = calendar.dateComponents([.day], from: cycle.startDate, to: date).day ?? 0
        if daysSinceStart < 0 { return nil }
        
        let cyclePosition = daysSinceStart % cycle.days
        guard cyclePosition < cycle.shiftOrder.count,
              let shift = cycle.shifts[safe: cycle.shiftOrder[cyclePosition]] else {
            return nil
        }
        
        // 获取对应日期的自定义颜色
        let dailyShift = cycle.dailySettings?.first(where: { $0.dayNumber == cyclePosition + 1 })
        let color = dailyShift?.customColor
        
        return (shift, color)
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [Event]
    let shift: (shift: ShiftType?, color: Color?)?
    private let calendar = Calendar.current
    private let chineseCalendar = ChineseCalendar.shared
    
    var body: some View {
        VStack(spacing: 2) {
            VStack {
                // 阳历日期
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 18))
                    .fontWeight(isSelected || isToday ? .medium : .regular)
                    .foregroundColor(isSelected ? .white : isToday ? .purple : .primary)
 
                // 农历日期
                Text(chineseCalendar.getLunarDate(date))
                    .font(.system(size: 8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(isSelected ? .white : isToday ? .purple : .primary)
            }
            .frame(width: 35, height: 35)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.purple.opacity(0.8))
                    } else if isToday {
                        Capsule().stroke(Color.purple, lineWidth: 1)
                    }
                }
            )

            
            // 班次显示
            if let shiftInfo = shift, let shift = shiftInfo.shift {
                Text(shift.name)
                    .font(.system(size: 9))
//                    .foregroundColor(shiftInfo.color ?? shift.displayColor)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background((shiftInfo.color ?? shift.displayColor).opacity(0.7))
                    .cornerRadius(3)
                    .fontWeight(.bold)
            }
        }
        .frame(height: 70)
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            // 节日角标
            if let festival = chineseCalendar.getFestival(date) {
                Text(festival)
                    .font(.system(size: 8))
                    .foregroundColor(.red)
                    .padding(2)
                    .offset(x: 10, y: -2)
            }
        }
    }
}

struct TodayPlanView: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's plan")
                .font(.headline)
                .foregroundColor(.gray)
            
            HStack {
                Text(event.date, style: .time)
                    .fontWeight(.semibold)
                
                Text(event.title)
                
                if let location = event.location {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(location)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UpcomingEventRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 15) {
            Rectangle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                Text(event.date.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}


// 月份选择器视图
struct MonthSelectorView: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    private let months = ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Text(formattedDate)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 150)
                .animation(.none, value: selectedDate)
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var formattedDate: String {
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        return "\(months[month-1]) \(year)"
    }
    
    private func previousMonth() {
        withAnimation {
            if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
    
    private func nextMonth() {
        withAnimation {
            if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }
}

// 星期标题视图
struct WeekdayHeaderView: View {
//    private let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let weekDays = ["一", "二", "三", "四", "五", "六", "日"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.gray)
                    .fontWeight(.bold)
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 0)
    }
}

// 事件列表视图
struct EventListView: View {
    let events: [Event]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(events,id:\.id) { event in
                EventRow(event: event)
            }
            .onDelete { indexSet in
                
            }
        }
    }
}

// 单个事件行视图
struct EventRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.system(size: 16, weight: .medium))
                Text(event.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if let location = event.location {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    Text(location)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Event.self, inMemory: true)
}
