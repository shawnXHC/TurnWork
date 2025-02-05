import SwiftUI
import SwiftData

struct ShiftScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShiftType.order) private var shiftTypes: [ShiftType]
    @Query private var cycles: [ShiftCycle]
    
    @State private var showingAddShiftType = false
    @State private var showingCycleOptions = false
    @State private var selectedCycle: ShiftCycle?
    @State private var showingDeleteAlert = false
    @State private var days = 5
    @State private var startDate = Date()
    @State private var cycleName = "默认周期"
    @State private var dailyShifts: [ShiftDailySetting] = []
    
    var activeCycle: ShiftCycle? {
        cycles.first(where: { $0.isActive })
    }
    
    var body: some View {
        List {
            // 现有周期选择
            Section {
                HStack {
                    Text("排班周期")
                    Spacer()
                    Menu {
                        ForEach(cycles) { cycle in
                            Button(action: {
                                loadCycle(cycle)
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
                        
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("删除当前周期", systemImage: "trash")
                        }
                        .disabled(activeCycle == nil)
                    } label: {
                        HStack {
                            Text(activeCycle?.name ?? "新建周期")
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            // 周期设置
            Section {
                TextField("周期名称", text: $cycleName)
                
                HStack {
                    Text("循环天数")
                    Spacer()
                    Stepper("\(days)天", value: $days, in: 1...30)
                        .onChange(of: days) { _ in
                            updateDailyShifts()
                        }
                }
                
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
            }
            
            // 班次类型管理
            Section("班次类型") {
                ForEach(shiftTypes) { shift in
                    HStack {
                        Circle()
                            .fill(shift.displayColor)
                            .frame(width: 12, height: 12)
                        Text(shift.name)
                        Spacer()
                        Text("\(shift.startTime.formatted(date: .omitted, time: .shortened)) - \(shift.endTime.formatted(date: .omitted, time: .shortened))")
                            .foregroundColor(.gray)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteShiftType(shift)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            editShiftType(shift)
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                
                Button("添加班次") {
                    showingAddShiftType = true
                }
            }
            
            // 排班设置
            if !shiftTypes.isEmpty {
                Section("排班设置") {
                    ForEach($dailyShifts) { $setting in
                        DailyShiftSettingView(setting: $setting, shiftTypes: shiftTypes)
                    }
                }
                
                Section {
                    Button(action: saveSchedule) {
                        Text(activeCycle == nil ? "保存新周期" : "更新周期")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.purple)
                }
            } else {
                Section {
                    Text("请先添加班次类型")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("排班设置")
        .sheet(isPresented: $showingAddShiftType) {
            AddShiftTypeView()
        }
        .alert("删除周期", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteCycle()
            }
        } message: {
            Text("确定要删除当前周期吗？此操作不可撤销。")
        }
        .onAppear {
            initializeSettings()
        }
    }
    
    private func loadCycle(_ cycle: ShiftCycle) {
        cycleName = cycle.name
        days = cycle.days
        startDate = cycle.startDate
        selectedCycle = cycle
        
        dailyShifts = (0..<cycle.days).map { index in
            let shift = cycle.shifts[safe: cycle.shiftOrder[index]] ?? shiftTypes.first
            let setting = cycle.dailySettings?.first(where: { $0.dayNumber == index + 1 })
            
            return ShiftDailySetting(
                dayNumber: index + 1,
                selectedShiftId: shift?.id ?? setting?.selectedShiftId,
                customStartTime: setting?.customStartTime,
                customEndTime: setting?.customEndTime,
                customColor: setting?.customColor
            )
        }
    }
    
    private func deleteCycle() {
        if let cycle = activeCycle {
            modelContext.delete(cycle)
            try? modelContext.save()
            
            // 重置表单
            cycleName = "默认周期"
            days = 5
            startDate = Date()
            selectedCycle = nil
            updateDailyShifts()
        }
    }
    
    private func deleteShiftType(_ shift: ShiftType) {
        modelContext.delete(shift)
        try? modelContext.save()
    }
    
    private func editShiftType(_ shift: ShiftType) {
        // 实现编辑功能
    }
    
    private func saveSchedule() {
        // 创建新的班次顺序数组
        let shiftOrder = dailyShifts.map { setting in
            shiftTypes.firstIndex(where: { $0.id == setting.selectedShiftId }) ?? 0
        }
        
        if let existingCycle = selectedCycle {
            // 更新现有周期
            existingCycle.name = cycleName
            existingCycle.days = days
            existingCycle.shifts = shiftTypes
            existingCycle.shiftOrder = shiftOrder
            existingCycle.startDate = startDate
            existingCycle.dailySettings = dailyShifts
            
            // 如果是激活的周期，保持激活状态
            if existingCycle.isActive {
                existingCycle.isActive = true
            }
        } else {
            // 停用其他周期
            for cycle in cycles {
                cycle.isActive = false
            }
            
            // 创建新周期
            let newCycle = ShiftCycle(
                name: cycleName,
                days: days,
                shifts: shiftTypes,
                shiftOrder: shiftOrder,
                startDate: startDate,
                isActive: true,
                dailySettings: dailyShifts
            )
            modelContext.insert(newCycle)
        }
        
        try? modelContext.save()
    }
    
    private func initializeSettings() {
        if let cycle = activeCycle {
            days = cycle.days
            startDate = cycle.startDate
            dailyShifts = (0..<cycle.days).map { index in
                let shift = cycle.shifts[safe: cycle.shiftOrder[index]] ?? shiftTypes.first
                return ShiftDailySetting(
                    dayNumber: index + 1,
                    selectedShiftId: shift?.id,
                    customStartTime: nil,
                    customEndTime: nil,
                    customColor: nil
                )
            }
        } else {
            updateDailyShifts()
        }
    }
    
    private func updateDailyShifts() {
        // 保持现有设置
        let existingSettings = dailyShifts
        dailyShifts = (0..<days).map { index in
            if index < existingSettings.count {
                var setting = existingSettings[index]
                setting.dayNumber = index + 1
                return setting
            } else {
                return ShiftDailySetting(
                    dayNumber: index + 1,
                    selectedShiftId: shiftTypes.first?.id,
                    customStartTime: nil,
                    customEndTime: nil,
                    customColor: nil
                )
            }
        }
    }
}

struct DailyShiftSettingView: View {
    @Binding var setting: ShiftDailySetting
    let shiftTypes: [ShiftType]
    @State private var showingCustomTime = false
    @State private var showingColorPicker = false
    
    private var selectedShift: ShiftType? {
        shiftTypes.first { $0.id == setting.selectedShiftId }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("第\(setting.dayNumber)天")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Menu {
                    ForEach(shiftTypes) { shift in
                        Button {
                            setting.selectedShiftId = shift.id
                            setting.customColor = nil
                        } label: {
                            HStack {
                                Circle()
                                    .fill(shift.displayColor)
                                    .frame(width: 12, height: 12)
                                Text(shift.name)
                                if setting.selectedShiftId == shift.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let shift = selectedShift {
                            Circle()
                                .fill(setting.customColor?.toSwiftUIColor ?? shift.displayColor)
                                .frame(width: 12, height: 12)
                            Text(shift.name)
                        } else {
                            Text("选择班次")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if selectedShift != nil {
                    Button {
                        showingColorPicker.toggle()
                    } label: {
                        Image(systemName: "paintpalette")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if let shift = selectedShift {
                HStack {
                    Text(shift.startTime.formatted(date: .omitted, time: .shortened))
                    Text("-")
                    Text(shift.endTime.formatted(date: .omitted, time: .shortened))
                    Spacer()
                    Button("自定义时间") {
                        showingCustomTime.toggle()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if showingCustomTime {
                HStack {
                    DatePicker("开始", selection: .init(
                        get: { setting.customStartTime ?? selectedShift?.startTime ?? Date() },
                        set: { setting.customStartTime = $0 }
                    ), displayedComponents: .hourAndMinute)
                    
                    DatePicker("结束", selection: .init(
                        get: { setting.customEndTime ?? selectedShift?.endTime ?? Date() },
                        set: { setting.customEndTime = $0 }
                    ), displayedComponents: .hourAndMinute)
                }
            }
        }
        .padding(.vertical, 5)
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: Binding(
                get: { setting.customColor ?? selectedShift?.displayColor ?? .blue },
                set: { setting.customColor = $0 }
            ))
        }
    }
}

struct ColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedColor: Color
    
    let colors: [Color] = [
        .red, .orange, .yellow, .green,
        .mint, .teal, .cyan, .blue,
        .indigo, .purple, .pink, .brown
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .opacity(selectedColor == color ? 1 : 0)
                            )
                            .shadow(color: .gray.opacity(0.2), radius: 2)
                            .onTapGesture {
                                selectedColor = color
                                dismiss()
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("选择颜色")
            .navigationBarItems(trailing: Button("完成") { dismiss() })
        }
    }
}

extension Color {
    var toSwiftUIColor: Color {
        self
    }
}

struct AddShiftTypeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ShiftType.order) private var existingShiftTypes: [ShiftType]
    
    @State private var name = ""
    @State private var color = Color.blue
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(8 * 3600)
    
    var body: some View {
        NavigationView {
            Form {
                TextField("班次名称", text: $name)
                ColorPicker("班次颜色", selection: $color)
                DatePicker("上班时间", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("下班时间", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            .navigationTitle("添加班次")
            .navigationBarItems(
                leading: Button("取消") { dismiss() },
                trailing: Button("保存") {
                    // 获取当前最大order值
                    let maxOrder = existingShiftTypes.map(\.order).max() ?? 0
                    let shiftType = ShiftType(
                        name: name,
                        color: color,
                        startTime: startTime,
                        endTime: endTime,
                        order: maxOrder + 1
                    )
                    modelContext.insert(shiftType)
                    try? modelContext.save()
                    dismiss()
                }
                .disabled(name.isEmpty)
            )
        }
    }
}

struct StatisticsView: View {
    let cycle: ShiftCycle
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    var statistics: ShiftStatistics {
        cycle.calculateStatistics(from: startDate, to: endDate)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("时间范围") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                }
                
                Section("统计结果") {
                    HStack {
                        Text("总天数")
                        Spacer()
                        Text("\(statistics.totalDays)天")
                    }
                    
                    HStack {
                        Text("总工时")
                        Spacer()
                        Text(String(format: "%.1f小时", statistics.totalHours))
                    }
                    
                    ForEach(Array(statistics.shiftCounts.keys.sorted()), id: \.self) { shiftName in
                        HStack {
                            Text(shiftName)
                            Spacer()
                            Text("\(statistics.shiftCounts[shiftName, default: 0])次")
                        }
                    }
                }
            }
            .navigationTitle("排班统计")
        }
    }
} 