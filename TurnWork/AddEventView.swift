import SwiftUI
import SwiftData

struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("标题", text: $title)
                DatePicker("日期", selection: $date)
                TextField("位置", text: $location)
                TextField("备注", text: $notes)
            }
            .navigationTitle("新建事项")
            .navigationBarItems(
                leading: Button("取消") { dismiss() },
                trailing: Button("保存") {
                    addEvent()
                    dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
    
    private func addEvent() {
        let event = Event(
            title: title,
            date: date,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(event)
        try? modelContext.save()
    }
} 
