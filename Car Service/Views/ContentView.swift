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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var vehicles: [Vehicle]
    
    @State private var selectedTab = 0
    // Tracks the vehicle shown in the Dashboard tab; defaults to first vehicle
    @State private var selectedVehicle: Vehicle?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Vehicles
            VehicleListView()
                .tabItem {
                    Label("Vehicles", systemImage: "car.fill")
                }
                .tag(0)
            
            // Tab 2: Dashboard
            DashboardView(selectedVehicle: selectedVehicle)
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
        .onAppear {
            // Default Dashboard to the first vehicle if available
            if selectedVehicle == nil, let firstVehicle = vehicles.first {
                selectedVehicle = firstVehicle
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
