import SwiftUI
import UserNotifications
import SwiftData
import AVFoundation
import AudioToolbox

// 添加重复类型枚举并实现 Codable
enum RepeatType: String, Codable, CaseIterable {
    case none = "不重复"
    case weekly = "按星期"
    case shift = "按班次"
}

// 闹钟数据模型
struct Alarm: Identifiable, Codable {
    let id: UUID
    var time: Date
    var label: String?
    var repeatType: RepeatType
    var repeatDays: Set<Int>
    var shiftTypeId: UUID?
    var sound: String
    var isEnabled: Bool
    
    init(id: UUID = UUID(), time: Date, label: String? = nil, 
         repeatType: RepeatType = .none, repeatDays: Set<Int> = [],
         shiftTypeId: UUID? = nil, sound: String = "default", isEnabled: Bool = true) {
        self.id = id
        self.time = time
        self.label = label
        self.repeatType = repeatType
        self.repeatDays = repeatDays
        self.shiftTypeId = shiftTypeId
        self.sound = sound
        self.isEnabled = isEnabled
    }
    
    enum CodingKeys: String, CodingKey {
        case id, time, label, repeatType, repeatDays, shiftTypeId, sound, isEnabled
    }
}

struct AlarmView: View {
    @StateObject private var alarmManager = AlarmManager.shared
    @State private var showingAddAlarm = false
    @Environment(\.modelContext) private var modelContext
    @Query private var shiftTypes: [ShiftType]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(alarmManager.alarms) { alarm in
                    AlarmRow(alarm: alarm, shiftTypes: shiftTypes)
                }
                .onDelete(perform: deleteAlarms)
            }
            .navigationTitle("闹钟")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAlarm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView(shiftTypes: shiftTypes)
            }
        }
    }
    
    private func deleteAlarms(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarmManager.alarms[index]
            alarmManager.removeAlarm(alarm)
        }
    }
}

// 闹钟行视图
struct AlarmRow: View {
    @StateObject private var alarmManager = AlarmManager.shared
    let alarm: Alarm
    let shiftTypes: [ShiftType]
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.time.formatted(date: .omitted, time: .shortened))
                    .font(.title2)
                
                if let label = alarm.label {
                    Text(label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 重复信息
                switch alarm.repeatType {
                case .weekly:
                    if !alarm.repeatDays.isEmpty {
                        Text(formatRepeatDays(alarm.repeatDays))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                case .shift:
                    if let shiftTypeId = alarm.shiftTypeId,
                       let shiftType = shiftTypes.first(where: { $0.id == shiftTypeId }) {
                        Text("按班次：\(shiftType.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                case .none:
                    Text("单次")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { newValue in
                    alarmManager.toggleAlarm(alarm, isEnabled: newValue)
                }
            ))
        }
        .padding(.vertical, 4)
    }
    
    private func formatRepeatDays(_ days: Set<Int>) -> String {
        if days.count == 7 {
            return "每天"
        }
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return days.sorted().map { weekdays[$0] }.joined(separator: " ")
    }
}

// 添加闹钟视图
struct AddAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var alarmManager = AlarmManager.shared
    
    @State private var time = Date()
    @State private var label = ""
    @State private var repeatType: RepeatType = .none
    @State private var repeatDays: Set<Int> = []
    @State private var selectedShiftType: ShiftType?
    @State private var sound = "default"
    
    let shiftTypes: [ShiftType]
    @Query(filter: #Predicate<ShiftCycle> { $0.isActive }) private var activeCycle: [ShiftCycle]
    
    private let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    private let sounds = [
        "default": "默认",
        "bell": "铃声",
        "chime": "风铃"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 180)
                    
                    TextField("标签", text: $label)
                }
                
                Section {
                    Picker("重复", selection: $repeatType) {
                        ForEach(RepeatType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    switch repeatType {
                    case .weekly:
                        ForEach(0..<7) { index in
                            Toggle(weekdays[index], isOn: Binding(
                                get: { repeatDays.contains(index) },
                                set: { isOn in
                                    if isOn {
                                        repeatDays.insert(index)
                                    } else {
                                        repeatDays.remove(index)
                                    }
                                }
                            ))
                        }
                    case .shift:
                        if let cycle = activeCycle.first {
                            Picker("选择班次", selection: $selectedShiftType) {
                                Text("无").tag(nil as ShiftType?)
                                ForEach(cycle.shifts) { shift in
                                    Text(shift.name)
                                        .tag(shift as ShiftType?)
                                }
                            }
                        } else {
                            Text("请先设置排班周期")
                                .foregroundColor(.secondary)
                        }
                    case .none:
                        EmptyView()
                    }
                }
                
                Section(header: Text("声音")) {
                    Picker("闹钟声音", selection: $sound) {
                        ForEach(Array(sounds.keys), id: \.self) { key in
                            Text(sounds[key]!)
                                .tag(key)
                        }
                    }
                }
            }
            .navigationTitle("添加闹钟")
            .navigationBarItems(
                leading: Button("取消") { dismiss() },
                trailing: Button("保存") {
                    saveAlarm()
                    dismiss()
                }
                .disabled(!isValidAlarm)
            )
        }
    }
    
    private var isValidAlarm: Bool {
        switch repeatType {
        case .weekly:
            return !repeatDays.isEmpty
        case .shift:
            return selectedShiftType != nil
        case .none:
            return true
        }
    }
    
    private func saveAlarm() {
        let alarm = Alarm(
            time: time,
            label: label.isEmpty ? nil : label,
            repeatType: repeatType,
            repeatDays: repeatType == .weekly ? repeatDays : [],
            shiftTypeId: selectedShiftType?.id,
            sound: sound,
            isEnabled: true
        )
        alarmManager.addAlarm(alarm)
    }
}

// 闹钟管理器
class AlarmManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = AlarmManager()
    
    @Published private(set) var alarms: [Alarm] = []
    private let userDefaults = UserDefaults.standard
    private let alarmsKey = "savedAlarms"
    private var isPlaying: Bool = false
    
    private override init() {
        super.init()
        loadAlarms()
        setupNotificationDelegate()
        setupAudioSession()
        requestNotificationPermission()
    }
    
    private func setupNotificationDelegate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("设置音频会话失败：\(error.localizedDescription)")
        }
    }
    
    // 实现 UNUserNotificationCenterDelegate 方法
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 允许前台显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 处理通知响应
        playAlarmSound()
        showAlarmAlert(for: response.notification)
        completionHandler()
    }
    
    private func playAlarmSound() {
        // 使用系统闹钟声音
        let systemSoundID: SystemSoundID = 1005  // 系统闹钟声音ID
        isPlaying = true
        
        // 持续播放系统声音和震动
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isPlaying {  // 如果没有停止，继续播放
                // 播放系统声音
                AudioServicesPlaySystemSound(systemSoundID)
                // 触发震动
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func stopAlarmSound() {
        // 停止所有系统声音
        AudioServicesDisposeSystemSoundID(1005)
        isPlaying = false  // 停止计时器
    }
    
    private func showAlarmAlert(for notification: UNNotification) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                // 创建闹钟提醒视图
                let alertController = UIAlertController(
                    title: notification.request.content.title,
                    message: notification.request.content.body,
                    preferredStyle: .alert
                )
                
                // 停止按钮
                let stopAction = UIAlertAction(title: "停止", style: .destructive) { [weak self] _ in
                    self?.stopAlarmSound()
                }
                
                // 稍后提醒按钮
                let snoozeAction = UIAlertAction(title: "稍后提醒", style: .default) { [weak self] _ in
                    self?.stopAlarmSound()
                    self?.scheduleSnooze(for: notification)
                }
                
                alertController.addAction(stopAction)
                alertController.addAction(snoozeAction)
                
                // 显示提醒
                rootViewController.present(alertController, animated: true)
            }
        }
    }
    
    private func scheduleSnooze(for notification: UNNotification) {
        let content = notification.request.content.mutableCopy() as! UNMutableNotificationContent
        content.title = "稍后提醒"
        content.sound = UNNotificationSound.default
        
        // 5分钟后再次提醒
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(notification.request.identifier)-snooze",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("通知权限已获取")
                } else if let error = error {
                    print("通知权限请求失败：\(error.localizedDescription)")
                }
            }
        }
    }
    
    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        scheduleNotification(for: alarm)
        saveAlarms()
    }
    
    func removeAlarm(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        cancelNotification(for: alarm)
        saveAlarms()
    }
    
    func toggleAlarm(_ alarm: Alarm, isEnabled: Bool) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index].isEnabled = isEnabled
            if isEnabled {
                scheduleNotification(for: alarms[index])
            } else {
                cancelNotification(for: alarm)
            }
            saveAlarms()
        }
    }
    
    private func scheduleNotification(for alarm: Alarm) {
        guard alarm.isEnabled else { return }
        
        let center = UNUserNotificationCenter.current()
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "闹钟"
        content.body = alarm.label ?? "闹钟时间到"
        
        // 设置通知声音
        switch alarm.sound {
        case "default":
            content.sound = .default
        case "bell":
            content.sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName("bell"))
        case "chime":
            content.sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName("chime"))
        default:
            content.sound = .default
        }
        
        // 创建触发器
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        
        if alarm.repeatDays.isEmpty {
            // 单次闹钟
            let now = Date()
            let today = Calendar.current.dateComponents([.hour, .minute], from: now)
            
            if today.hour! > dateComponents.hour! || 
               (today.hour! == dateComponents.hour! && today.minute! >= dateComponents.minute!) {
                // 如果时间已过，设置为明天
                if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) {
                    dateComponents = Calendar.current.dateComponents([.hour, .minute], from: tomorrow)
                }
            }
        } else {
            // 重复闹钟，添加重复日期
            for day in alarm.repeatDays {
                let identifier = "\(alarm.id.uuidString)-\(day)"
                var components = dateComponents
                components.weekday = day + 1 // 转换为日历weekday（1-7）
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("添加重复通知失败：\(error.localizedDescription)")
                    }
                }
            }
            return
        }
        
        // 单次闹钟的触发器
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // 添加通知请求
        center.add(request) { error in
            if let error = error {
                print("添加通知失败：\(error.localizedDescription)")
            } else {
                print("成功设置闹钟：\(dateComponents)")
            }
        }
    }
    
    private func cancelNotification(for alarm: Alarm) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [alarm.id.uuidString]
        )
    }
    
    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            userDefaults.set(encoded, forKey: alarmsKey)
        }
    }
    
    private func loadAlarms() {
        if let data = userDefaults.data(forKey: alarmsKey),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
            // 重新设置所有启用的闹钟
            for alarm in alarms where alarm.isEnabled {
                scheduleNotification(for: alarm)
            }
        }
    }
} 