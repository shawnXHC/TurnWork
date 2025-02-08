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
                        
                        // 添加饼图
                        ShiftDistributionPieChart(statistics: stats)
                        
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

// 班次统计柱状图
struct ShiftCountBarChart: View {
    let statistics: ShiftStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("班次统计")
                .font(.headline)
            
            Chart {
                ForEach(Array(statistics.shiftCounts.keys.sorted()), id: \.self) { shiftName in
                    let count = statistics.shiftCounts[shiftName, default: 0]
                    
                    BarMark(
                        x: .value("Type", shiftName),
                        y: .value("Count", count)
                    )
                    .foregroundStyle(by: .value("Type", shiftName))
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .top, spacing: 4) {
                        Text("\(count)次")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background {
                                Capsule()
                                    .fill(.white.opacity(0.8))
                            }
                    }
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let shiftName = value.as(String.self) {
                            Text(shiftName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 5)
    }
}

// 添加饼图组件
struct ShiftDistributionPieChart: View {
    let statistics: ShiftStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("班次分布")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 20) {
                // 饼图
                Chart {
                    ForEach(Array(statistics.shiftCounts.keys.sorted()), id: \.self) { shiftName in
                        SectorMark(
                            angle: .value("Count", statistics.shiftCounts[shiftName, default: 0]),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Type", shiftName))
                    }
                }
                .frame(width: 180, height: 180)
                .chartLegend(.hidden)
                
                // 图例和数据
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(statistics.shiftCounts.keys.sorted()), id: \.self) { shiftName in
                        let count = statistics.shiftCounts[shiftName, default: 0]
                        let percentage = Double(count) / Double(statistics.totalDays) * 100
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hue: Double(statistics.shiftCounts.keys.sorted().firstIndex(of: shiftName)!) / Double(statistics.shiftCounts.count), 
                                      saturation: 0.5, 
                                      brightness: 0.8))
                                .frame(width: 8, height: 8)
                            
                            Text(shiftName)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(count)次")
                                .font(.system(size: 12, weight: .medium))
                            
                            Text(String(format: "%.0f%%", percentage))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
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