import SwiftUI
import SwiftData
import Charts

struct StatisticsTabView: View {
    @Query private var cycles: [ShiftCycle]
    @State private var selectedTimeRange: TimeRange = .month
    @State private var startDate: Date
    @State private var endDate: Date
    
    enum TimeRange {
        case month, year
        
        var title: String {
            switch self {
            case .month: return "本月"
            case .year: return "全年"
            }
        }
    }
    
    init() {
        let calendar = Calendar.current
        let now = Date()
        
        // 初始化为本月开始和结束日期
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        let startComponents = DateComponents(year: year, month: month, day: 1)
        let endComponents = DateComponents(year: year, month: month + 1, day: 0)
        
        _startDate = State(initialValue: calendar.date(from: startComponents) ?? now)
        _endDate = State(initialValue: calendar.date(from: endComponents) ?? now)
    }
    
    var activeCycle: ShiftCycle? {
        cycles.first(where: { $0.isActive })
    }
    
    var statistics: ShiftStatistics? {
        guard let cycle = activeCycle else { return nil }
        return cycle.calculateStatistics(from: startDate, to: endDate)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 时间范围选择器
                    Picker("时间范围", selection: $selectedTimeRange) {
                        Text("本月").tag(TimeRange.month)
                        Text("全年").tag(TimeRange.year)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .onChange(of: selectedTimeRange) { _ in
                        updateDateRange()
                    }
                    
                    if let stats = statistics {
                        // 总览卡片
                        StatisticsOverviewCard(statistics: stats)
                        
                        // 班次分布饼图
                        ShiftDistributionChart(statistics: stats)
                        
                        // 每日工时折线图
                        DailyHoursChart(cycle: activeCycle!, startDate: startDate, endDate: endDate)
                        
                        // 班次统计柱状图
                        ShiftCountBarChart(statistics: stats)
                    } else {
                        ContentUnavailableView("暂无数据", 
                            systemImage: "chart.bar.xaxis",
                            description: Text("请先设置排班周期"))
                    }
                }
                .padding()
            }
            .navigationTitle("工作统计")
        }
    }
    
    private func updateDateRange() {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeRange {
        case .month:
            let month = calendar.component(.month, from: now)
            let year = calendar.component(.year, from: now)
            let startComponents = DateComponents(year: year, month: month, day: 1)
            let endComponents = DateComponents(year: year, month: month + 1, day: 0)
            startDate = calendar.date(from: startComponents) ?? now
            endDate = calendar.date(from: endComponents) ?? now
            
        case .year:
            let year = calendar.component(.year, from: now)
            let startComponents = DateComponents(year: year, month: 1, day: 1)
            let endComponents = DateComponents(year: year, month: 12, day: 31)
            startDate = calendar.date(from: startComponents) ?? now
            endDate = calendar.date(from: endComponents) ?? now
        }
    }
}

// 总览卡片视图
struct StatisticsOverviewCard: View {
    let statistics: ShiftStatistics
    
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 30) {
                StatItem(title: "总工作天数", value: "\(statistics.totalDays)天")
                StatItem(title: "总工作时长", value: String(format: "%.1f小时", statistics.totalHours))
                StatItem(title: "日均工时", value: String(format: "%.1f小时", 
                    statistics.totalDays > 0 ? statistics.totalHours / Double(statistics.totalDays) : 0))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
}

// 班次分布饼图
struct ShiftDistributionChart: View {
    let statistics: ShiftStatistics
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("班次分布")
                .font(.headline)
            
            Chart {
                ForEach(Array(statistics.shiftCounts.keys.sorted()), id: \.self) { shiftName in
                    SectorMark(
                        angle: .value("Count", statistics.shiftCounts[shiftName, default: 0]),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Type", shiftName))
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
}

// 每日工时折线图
struct DailyHoursChart: View {
    let cycle: ShiftCycle
    let startDate: Date
    let endDate: Date
    
    var dailyData: [(date: Date, hours: Double)] {
        cycle.getShifts(from: startDate, to: endDate).map { ($0.date, $0.shift.workHours) }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("每日工时")
                .font(.headline)
            
            Chart(dailyData, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Hours", item.hours)
                )
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Hours", item.hours)
                )
                .foregroundStyle(.purple.opacity(0.1))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
}

// 班次统计柱状图
struct ShiftCountBarChart: View {
    let statistics: ShiftStatistics
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("班次统计")
                .font(.headline)
            
            Chart {
                ForEach(Array(statistics.shiftCounts.keys.sorted()), id: \.self) { shiftName in
                    BarMark(
                        x: .value("Type", shiftName),
                        y: .value("Count", statistics.shiftCounts[shiftName, default: 0])
                    )
                    .foregroundStyle(by: .value("Type", shiftName))
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
}

// 统计项组件
struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.headline)
        }
    }
} 