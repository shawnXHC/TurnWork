import SwiftUI
import SwiftData

struct ShiftScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShiftType.order) private var shiftTypes: [ShiftType]
    @Query private var cycles: [ShiftCycle]
    
    @State private var showingAddShiftType = false
    @State private var showingEditShiftType = false
    @State private var showingCycleEdit = false
    @State private var showingDeleteAlert = false
    @State private var selectedShiftType: ShiftType?
    @State private var selectedCycle: ShiftCycle? = nil
    @State private var cycleEditMode = false
    
    var body: some View {
        List {
            // 班次管理部分
            Section {
                ForEach(shiftTypes) { shift in
                    ShiftTypeRow(
                        shift: shift,
                        onTap: {
                            selectedShiftType = shift
                            showingEditShiftType = true
                        },
                        onDelete: {
                            deleteShiftTypeWithConfirmation(shift)
                        },
                        isInUse: isShiftInUse(shift)
                    )
                }
                
                Button(action: { showingAddShiftType = true }) {
                    Label("添加班次", systemImage: "plus.circle")
                }
            } header: {
                Text("班次管理")
            } footer: {
                Text("带锁定标记的班次正在被使用，不可删除")
            }
            
            // 排班周期列表
            Section {
                ForEach(cycles) { cycle in
                    CycleRow(cycle: cycle, isActive: cycle.isActive) {
                        toggleCycleActive(cycle)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !cycle.isActive {
                            Button(role: .destructive) {
                                selectedCycle = cycle
                                showingDeleteAlert = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        
                        Button {
                            selectedCycle = cycle
                            cycleEditMode = true
                            showingCycleEdit = true
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                
                Button(action: { 
                    selectedCycle = nil
                    cycleEditMode = false
                    showingCycleEdit = true
                }) {
                    Label("新建周期", systemImage: "plus.circle")
                }
            } header: {
                Text("排班周期")
            } footer: {
                Text("正在使用的排班周期不可删除，但可以编辑")
            }
        }
        .navigationTitle("排班设置")
        .sheet(isPresented: $showingAddShiftType) {
            AddShiftTypeView()
        }
        .sheet(isPresented: $showingEditShiftType) {
            if let shift = selectedShiftType {
                EditShiftTypeView(shiftType: shift)
            }
        }
        .sheet(isPresented: $showingCycleEdit) {
            if let cycle = selectedCycle {
                CycleEditView(cycle: cycle, isEditing: true)
            } else {
                CycleEditView(cycle: nil, isEditing: false)
            }
        }
        .onChange(of: showingCycleEdit) { newValue in
            if !newValue {  // sheet 关闭时
                selectedCycle = nil
                cycleEditMode = false
            }
        }
        .alert("删除周期", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let cycle = selectedCycle {
                    deleteCycle(cycle)
                }
            }
        } message: {
            Text("确定要删除这个排班周期吗？此操作不可撤销。")
        }
    }
    
    private func toggleCycleActive(_ cycle: ShiftCycle) {
        // 停用其他周期
        for otherCycle in cycles {
            otherCycle.isActive = false
        }
        // 启用选中的周期
        cycle.isActive = true
        try? modelContext.save()
    }
    
    private func deleteCycle(_ cycle: ShiftCycle) {
        // 检查是否是活动周期
        if cycle.isActive {
            // 显示错误提示
            let alert = UIAlertController(
                title: "无法删除",
                message: "正在使用的排班周期不能删除",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
            return
        }
        
        // 清除周期的班次引用，但不删除班次本身
        cycle.shifts = []
        cycle.shiftOrder = []
        cycle.dailySettings = []
        
        // 删除周期
        modelContext.delete(cycle)
        try? modelContext.save()
        selectedCycle = nil
    }
    
    private func isShiftInUse(_ shift: ShiftType) -> Bool {
        cycles.contains { cycle in
            cycle.shifts.contains { $0.id == shift.id }
        }
    }
    
    private func deleteShiftTypeWithConfirmation(_ shift: ShiftType) {
        if isShiftInUse(shift) {
            // 显示警告
            let alert = UIAlertController(
                title: "无法删除",
                message: "该班次正在被使用，请先从排班周期中移除。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
        } else {
            // 显示确认对话框
            let alert = UIAlertController(
                title: "删除班次",
                message: "确定要删除这个班次吗？此操作不可撤销。",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                modelContext.delete(shift)
                try? modelContext.save()
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
        }
    }
}

// 班次行组件
struct ShiftTypeRow: View {
    let shift: ShiftType
    let onTap: () -> Void
    let onDelete: () -> Void
    let isInUse: Bool
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(shift.displayColor)
                    .frame(width: 12, height: 12)
                Text(shift.name)
                Spacer()
                Text("\(shift.startTime.formatted(date: .omitted, time: .shortened)) - \(shift.endTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundColor(.gray)
                
                if isInUse {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if !isInUse {
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }
}

// 周期行组件
struct CycleRow: View {
    let cycle: ShiftCycle
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(cycle.name)
                        .foregroundColor(.primary)
                    Text("\(cycle.days)天循环")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct DailyShiftSettingView: View {
    @Binding var setting: ShiftDailySetting
    let shiftTypes: [ShiftType]
    
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
            
            Menu {
                ForEach(shiftTypes) { shift in
                    Button {
                        setting.selectedShiftId = shift.id
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
                            .fill(shift.displayColor)
                            .frame(width: 12, height: 12)
                        Text(shift.name)
                        
                        Spacer()
                        
                        Text(shift.startTime.formatted(date: .omitted, time: .shortened))
                        Text("-")
                        Text(shift.endTime.formatted(date: .omitted, time: .shortened))
                            .foregroundColor(.gray)
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
        }
        .padding(.vertical, 5)
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

struct EditShiftTypeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let shiftType: ShiftType
    
    @State private var name: String
    @State private var color: Color
    @State private var startTime: Date
    @State private var endTime: Date
    
    init(shiftType: ShiftType) {
        self.shiftType = shiftType
        _name = State(initialValue: shiftType.name)
        _color = State(initialValue: shiftType.displayColor)
        _startTime = State(initialValue: shiftType.startTime)
        _endTime = State(initialValue: shiftType.endTime)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("班次名称", text: $name)
                ColorPicker("班次颜色", selection: $color)
                DatePicker("上班时间", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("下班时间", selection: $endTime, displayedComponents: .hourAndMinute)
            }
            .navigationTitle("编辑班次")
            .navigationBarItems(
                leading: Button("取消") { dismiss() },
                trailing: Button("保存") {
                    updateShiftType()
                    dismiss()
                }
                .disabled(name.isEmpty)
            )
        }
    }
    
    private func updateShiftType() {
        shiftType.name = name
        
        // 转换Color为RGB值
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        shiftType.color = (Int(red * 255) << 16) |
                         (Int(green * 255) << 8) |
                         Int(blue * 255)
        
        shiftType.startTime = startTime
        shiftType.endTime = endTime
        
        try? modelContext.save()
    }
}

struct CycleEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ShiftType.order) private var shiftTypes: [ShiftType]
    @Query private var cycles: [ShiftCycle]
    
    let cycle: ShiftCycle?
    let isEditing: Bool
    @State private var name: String
    @State private var days: Int
    @State private var startDate: Date
    @State private var dailyShifts: [ShiftDailySetting]
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingDiscardAlert = false  // 添加放弃更改提示
    
    // 修改数据变更检测逻辑
    private var hasChanges: Bool {
        if let existingCycle = cycle {
            // 编辑现有周期时检查所有字段的变化
            return name != existingCycle.name ||
                days != existingCycle.days ||
                !Calendar.current.isDate(startDate, inSameDayAs: existingCycle.startDate) ||
                dailyShifts != existingCycle.dailySettings
        } else {
            // 新建周期时只检查是否有输入内容
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                days != 5 ||  // 5是初始默认值
                dailyShifts.contains(where: { $0.selectedShiftId != nil })
        }
    }
    
    init(cycle: ShiftCycle?, isEditing: Bool) {
        self.cycle = cycle
        self.isEditing = isEditing
        
        // 初始化值，新建时不设置默认值
        _name = State(initialValue: cycle?.name ?? "")  // 移除默认名称
        _days = State(initialValue: cycle?.days ?? 5)
        _startDate = State(initialValue: cycle?.startDate ?? Date())
        
        // 初始化每日设置
        if let existingCycle = cycle {
            // 编辑现有周期时，使用现有的设置
            _dailyShifts = State(initialValue: existingCycle.dailySettings ?? [])
        } else {
            // 新建周期时，不设置任何默认数据
            _dailyShifts = State(initialValue: [])
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("周期名称", text: $name)
                        .textInputAutocapitalization(.never)
                        .placeholder(when: name.isEmpty) {
                            Text("请输入周期名称")
                                .foregroundColor(.gray)
                        }
                    
                    Stepper("循环天数: \(days)天", value: $days, in: 1...30)
                        .onChange(of: days) { _ in
                            updateDailyShifts()
                        }
                    
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                }
                
                if !shiftTypes.isEmpty {
                    Section("排班设置") {
                        ForEach($dailyShifts) { $setting in
                            DailyShiftSettingView(setting: $setting, shiftTypes: shiftTypes)
                        }
                    }
                } else {
                    Section {
                        Text("请先添加班次类型")
                            .foregroundColor(.red)
                    }
                }
                
                if isEditing {
                    Section {
                        if cycle?.isActive == true {
                            Text("当前周期正在使用中")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑周期" : "新建周期")
            .navigationBarItems(
                leading: Button("取消") {
                    if hasChanges {
                        showingDiscardAlert = true
                    } else {
                        dismiss()
                    }
                },
                trailing: Button("保存") {
                    if validateInput() {
                        saveCycle()
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("放弃更改", isPresented: $showingDiscardAlert) {
                Button("取消", role: .cancel) { }
                Button("放弃", role: .destructive) { dismiss() }
            } message: {
                Text(isEditing ? "是否放弃未保存的更改？" : "是否放弃新建周期？")
            }
            .onAppear {
                if dailyShifts.isEmpty {
                    updateDailyShifts()
                }
            }
        }
    }
    
    private func validateInput() -> Bool {
        // 验证名称
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            alertMessage = "请输入周期名称"
            showingAlert = true
            return false
        }
        
        // 验证名称唯一性（排除当前编辑的周期）
        if cycles.contains(where: { 
            $0.name == trimmedName && $0.id != cycle?.id 
        }) {
            alertMessage = "周期名称已存在"
            showingAlert = true
            return false
        }
        
        // 验证是否所有天数都选择了班次
        if dailyShifts.contains(where: { $0.selectedShiftId == nil }) {
            alertMessage = "请为每一天选择班次"
            showingAlert = true
            return false
        }
        
        return true
    }
    
    private func updateDailyShifts() {
        let existingSettings = dailyShifts
        dailyShifts = (0..<days).map { index in
            if index < existingSettings.count {
                // 保持现有设置
                var setting = existingSettings[index]
                setting.dayNumber = index + 1
                return setting
            } else {
                // 创建新设置，不设置默认班次
                return ShiftDailySetting(
                    dayNumber: index + 1,
                    selectedShiftId: nil
                )
            }
        }
    }
    
    private func saveCycle() {
        let shiftOrder = dailyShifts.map { setting in
            shiftTypes.firstIndex(where: { $0.id == setting.selectedShiftId }) ?? 0
        }
        
        if isEditing, let existingCycle = cycle {
            // 更新现有周期
            existingCycle.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existingCycle.days = days
            existingCycle.shifts = shiftTypes
            existingCycle.shiftOrder = shiftOrder
            existingCycle.startDate = startDate
            existingCycle.dailySettings = dailyShifts
            
            // 如果是唯一的周期，保持激活状态
            if cycles.count == 1 {
                existingCycle.isActive = true
            }
        } else {
            // 创建新周期
            let newCycle = ShiftCycle(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                days: days,
                shifts: shiftTypes,
                shiftOrder: shiftOrder,
                startDate: startDate,
                isActive: cycles.isEmpty,
                dailySettings: dailyShifts
            )
            modelContext.insert(newCycle)
        }
        
        try? modelContext.save()
    }
}

// 添加 View 扩展来支持 placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
} 
