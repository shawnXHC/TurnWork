//
//  TurnWorkApp.swift
//  TurnWork
//
//  Created by seanxia on 2025/1/15.
//

import SwiftUI
import SwiftData

@main
struct TurnWorkApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Event.self,
            ShiftType.self,
            ShiftCycle.self,
            ShiftDailySetting.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}

