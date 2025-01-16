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
                TextField("Title", text: $title)
                DatePicker("Date", selection: $date)
                TextField("Location", text: $location)
                TextField("Notes", text: $notes)
            }
            .navigationTitle("New Event")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
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