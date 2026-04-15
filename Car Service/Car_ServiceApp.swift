//
//  Car_ServiceApp.swift
//  Car Service
//
//  Created by Scott Campbell on 4/15/26.
//

import SwiftUI
import SwiftData

@main
struct Car_ServiceApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Vehicle.self,
            ServiceRecord.self,
            VehiclePhoto.self,
            UpcomingService.self
        ])
        
        // Enable iCloud sync via CloudKit
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
