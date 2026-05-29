//
//  ContentView.swift
//  Car Service
//
//  Main tab view with 3 tabs: Vehicles, Dashboard, Settings
//  Service history & adding services are accessed from the Vehicle Detail view
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Vehicles
            VehicleListView()
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
            
            // Tab 3: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
