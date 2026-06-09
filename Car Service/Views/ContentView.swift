//
//  ContentView.swift
//  Car Service
//
//  Main tab view with 3 tabs: Vehicles, Dashboard, Settings
//  Service history & adding services are accessed from the Vehicle Detail view
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // Tab 1: Vehicles
            VehicleListView()
                .environmentObject(appState)
                .tabItem {
                    Label("Vehicles", systemImage: "car.fill")
                }
                .tag(0)
            
            // Tab 2: Dashboard
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent")
                }
                .tag(1)
            
            // Tab 3: Service History
            ServiceHistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet.clipboard")
                }
                .tag(2)
            
            // Tab 4: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
