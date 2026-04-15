//
//  ContentView.swift
//  Car Service
//
//  Main tab view with 5 tabs: Vehicles, Services, Add Service, Dashboard, Settings
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var vehicles: [Vehicle]
    
    @State private var selectedTab = 0
    @State private var selectedVehicle: Vehicle?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Vehicles
            VehicleListView(selectedVehicle: $selectedVehicle)
                .tabItem {
                    Label("Vehicles", systemImage: "car.fill")
                }
                .tag(0)
            
            // Tab 2: Services
            ServiceHistoryView(selectedVehicle: selectedVehicle)
                .tabItem {
                    Label("Services", systemImage: "list.bullet.clipboard")
                }
                .tag(1)
            
            // Tab 3: Add Service
            AddServiceView(selectedVehicle: selectedVehicle)
                .tabItem {
                    Label("Add Service", systemImage: "plus.circle.fill")
                }
                .tag(2)
            
            // Tab 4: Dashboard
            DashboardView(selectedVehicle: selectedVehicle)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent")
                }
                .tag(3)
            
            // Tab 5: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .onAppear {
            // Select first vehicle by default if available
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
