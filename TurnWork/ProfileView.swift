import SwiftUI
import SwiftData

// 将 AllCyclesView 移到文件顶层
struct AllCyclesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShiftType.order) private var shiftTypes: [ShiftType]
    @Query(sort: \ShiftCycle.name) private var cycles: [ShiftCycle]
    @State private var selectedMonth = Date()
    
    // 获取选中月份的所有日期
    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }
    
    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7  // 周日或周六
    }
    
    private func dateColumnView(_ date: Date) -> some View {
        VStack(spacing: 2) {
            // 星期几
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 12))
                .foregroundColor(isWeekend(date) ? .red.opacity(0.8) : .secondary)
            
            // 日期
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 16, weight: isToday(date) ? .bold : .medium))
                .foregroundColor(
                    isToday(date) ? .white :
                    isWeekend(date) ? .red : .primary
                )
        }
        .frame(width: 50)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isToday(date) ? Color.blue :
                    isWeekend(date) ? Color.red.opacity(0.1) : Color.clear
                )
        )
    }
    
    // 修改列宽计算逻辑
    private var columnWidth: CGFloat {
        // 基础宽度，根据设备宽度和列数计算
        let baseWidth = UIScreen.main.bounds.width
        let dateColumnWidth: CGFloat = 50 // 日期列固定宽度
        let spacing: CGFloat = 0 // 列间距
        let safeAreaInsets: CGFloat = 20 // 安全区域边距
        
        // 计算剩余可用宽度
        let availableWidth = baseWidth - dateColumnWidth - safeAreaInsets
        
        if cycles.isEmpty {
            return availableWidth
        }
        
        // 当列数少于3时，平均分配宽度
        if cycles.count <= 3 {
            return availableWidth / CGFloat(max(1, cycles.count))
        }
        
        // 列数较多时，设置最小和最大宽度限制
        let minWidth: CGFloat = 80
        let calculatedWidth = max(minWidth, availableWidth / CGFloat(cycles.count))
        return min(calculatedWidth, 120)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 月份选择器
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .padding(.horizontal, 4)
                
                Text(selectedMonth.formatted(.dateTime.year().month()))
                    .font(.title3.bold())
                    .frame(minWidth: 120)
                    .foregroundColor(.indigo)
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .padding(.horizontal, 4)
            }
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
            )
            
            // 表格内容
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 表头
                    HStack(alignment: .center, spacing: 0) {
                        // 左侧固定列
                        Text("日期")
                            .font(.subheadline.bold())
                            .foregroundColor(.indigo)
                            .frame(width: 50)
                            .padding(.vertical, 12)
                            .background(
                                Rectangle()
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                            )
                        
                        // 周期列
                        ForEach(cycles) { cycle in
                            VStack(spacing: 4) {
                                Text(cycle.name)
                                    .font(.headline)
                                    .foregroundColor(cycle.isActive ? .blue : .primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                if cycle.isActive {
                                    Text("使用中")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Color.blue.gradient)
                                        )
                                }
                            }
                            .frame(width: columnWidth)
                            .padding(.vertical, 8)
                            .background(
                                Rectangle()
                                    .fill(cycle.isActive ? 
                                         Color.blue.opacity(0.05) : 
                                         Color(.systemBackground))
                            )
                        }
                    }
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
                    
                    // 日期和班次内容
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(daysInMonth, id: \.self) { date in
                                HStack(spacing: 0) {
                                    // 日期列
                                    dateColumnView(date)
                                        .background(Color(.systemBackground))
                                    
                                    // 班次列
                                    ForEach(cycles) { cycle in
                                        if let shiftType = cycle.getShift(for: date) {
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(shiftType.displayColor)
                                                    .frame(width: 8, height: 8)
                                                Text(shiftType.name)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            .frame(width: columnWidth)
                                            .padding(.vertical, 8)
                                            .background(
                                                Rectangle()
                                                    .fill(
                                                        cycle.isActive ?
                                                        Color.blue.opacity(0.05) :
                                                        Color(.systemBackground).opacity(0.6)
                                                    )
                                            )
                                        } else {
                                            Text("-")
                                                .foregroundColor(.gray)
                                                .frame(width: columnWidth)
                                                .padding(.vertical, 8)
                                                .background(Color(.systemBackground))
                                        }
                                    }
                                }
                                Divider()
                                    .opacity(0.3)
                            }
                        }
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("排班汇总")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 0)
                .background(.bar)
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
}

// 添加关于页面视图
struct AboutView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // App Logo
                VStack(spacing: 16) {
//                    Image(systemName: "clock.circle.fill")
//                        .font(.system(size: 80))
//                        .foregroundStyle(.blue.gradient)
                    Image("AboutIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width:80,height: 80)
                        .foregroundStyle(.blue.gradient)
                        .cornerRadius(20)
                    
                    Text("便捷轮班")
                        .font(.title.bold())
                        .foregroundColor(.primary)
                    
                    Text("Version 1.2.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // 功能介绍
                VStack(spacing: 20) {
                    FeatureRow(icon: "calendar.badge.clock", 
                             title: "排班管理",
                             description: "灵活设置排班规则，轻松管理工作时间")
                    
                    FeatureRow(icon: "chart.bar.fill", 
                             title: "数据统计",
                             description: "直观展示工作统计，助您合理安排时间")
                    
                }
                .padding(.horizontal)
                
                // 开发者信息
//                VStack(spacing: 12) {
//                    Text("开发者")
//                        .font(.headline)
//                        .foregroundColor(.secondary)
//                    
//                    Button {
//                        openURL(URL(string: "https://github.com/seanxia")!)
//                    } label: {
//                        HStack(spacing: 8) {
//                            Image(systemName: "link")
//                                .font(.caption)
//                            Text("@seanxia")
//                                .font(.subheadline)
//                        }
//                        .foregroundColor(.blue)
//                    }
//                }
//                .padding(.top)
                
                Spacer()
                
                // 版权信息
//                Text("© 2024 轮班助手. All rights reserved.")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .padding(.bottom, 20)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 功能介绍行组件
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        )
    }
}

struct ProfileView: View {
    @State private var showingShiftSchedule = false
    @State private var showingAllCycles = false
    @AppStorage("userName") private var userName = "未设置"
    @AppStorage("userRole") private var userRole = "职员"
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息区域
                Section {
                    HStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.medium)
                            
                            Text(userRole)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Button {
                            showingEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 功能列表
                Section {
                    NavigationLink(destination: ShiftScheduleView()) {
                        ProfileRowView(
                            icon: "clock.badge.checkmark.fill",
                            iconColor: .purple,
                            title: "排班设置"
                        )
                    }
                    
                    NavigationLink(destination: AllCyclesView()) {
                        ProfileRowView(
                            icon: "calendar.badge.clock",
                            iconColor: .blue,
                            title: "排班汇总"
                        )
                    }
                }
                
                // 系统设置
                Section {
                    NavigationLink(destination: AboutView()) {
                        ProfileRowView(
                            icon: "info.circle.fill",
                            iconColor: .blue,
                            title: "关于"
                        )
                    }
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(userName: $userName, userRole: $userRole)
            }
        }
    }
    
    private func exportData() {
        // 导出数据的实现
    }
}

// 个人资料编辑视图
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var userName: String
    @Binding var userRole: String
    @State private var tempUserName: String = ""
    @State private var tempUserRole: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("姓名", text: $tempUserName)
                    TextField("职位", text: $tempUserRole)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarItems(
                leading: Button("取消") { dismiss() },
                trailing: Button("保存") {
                    userName = tempUserName
                    userRole = tempUserRole
                    dismiss()
                }
            )
            .onAppear {
                tempUserName = userName
                tempUserRole = userRole
            }
        }
    }
}

// 个人页面行视图组件
struct ProfileRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 5)
    }
}

#Preview {
    ProfileView()
} 
