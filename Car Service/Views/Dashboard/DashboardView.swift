//
//  DashboardView.swift
//  Car Service
//
//  Dashboard showing upcoming maintenance needs for all vehicles
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var vehicles: [Vehicle]
    
    let selectedVehicle: Vehicle?
    
    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    EmptyDashboardView()
                } else {
                    dashboardList
                }
            }
            .navigationTitle("Dashboard")
        }
    }
    
    // Dashboard list showing all vehicles
    private var dashboardList: some View {
        List {
            ForEach(vehicles) { vehicle in
                DashboardVehicleCard(vehicle: vehicle, isSelected: selectedVehicle?.id == vehicle.id)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Dashboard Vehicle Card
struct DashboardVehicleCard: View {
    let vehicle: Vehicle
    let isSelected: Bool
    
    // Get upcoming (non-completed) services for this vehicle
    private var upcomingServices: [UpcomingService] {
        vehicle.upcomingServices?.filter { !$0.isCompleted }.sorted { $0.targetMileage < $1.targetMileage } ?? []
    }
    
    // Oil change status
    private var oilChangeStatus: (milesUntil: Int?, status: Status) {
        guard let milesUntil = vehicle.milesUntilOilChange else {
            return (nil, .unknown)
        }
        
        if milesUntil < 0 {
            return (milesUntil, .overdue)
        } else if milesUntil < 500 {
            return (milesUntil, .dueSoon)
        } else {
            return (milesUntil, .good)
        }
    }
    
    enum Status {
        case good, dueSoon, overdue, unknown
        
        var color: Color {
            switch self {
            case .good: return .green
            case .dueSoon: return .orange
            case .overdue: return .red
            case .unknown: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .dueSoon: return "exclamationmark.triangle.fill"
            case .overdue: return "xmark.octagon.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
        
        var label: String {
            switch self {
            case .good: return "Good"
            case .dueSoon: return "Due Soon"
            case .overdue: return "OVERDUE"
            case .unknown: return "No Data"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Vehicle Header
            HStack {
                // Thumbnail
                if let thumbnail = vehicle.thumbnailPhoto,
                   let image = thumbnail.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "car.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.displayName)
                        .font(.headline)
                    Text("\(vehicle.currentMileage) mi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            // Oil Change Status
            HStack {
                Image(systemName: oilChangeStatus.status.icon)
                    .foregroundColor(oilChangeStatus.status.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Oil Change")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(oilChangeStatus.status.label)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(oilChangeStatus.status.color)
                    }
                    
                    if let milesUntil = oilChangeStatus.milesUntil {
                        if milesUntil < 0 {
                            Text("Overdue by \(-milesUntil) miles")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("\(milesUntil) miles remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No oil change recorded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Upcoming Services
            if !upcomingServices.isEmpty {
                Divider()
                
                Text("Upcoming Maintenance")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                ForEach(upcomingServices.prefix(3)) { upcoming in
                    UpcomingServiceRow(upcoming: upcoming, currentMileage: vehicle.currentMileage)
                }
                
                if upcomingServices.count > 3 {
                    Text("+ \(upcomingServices.count - 3) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
    }
}

// MARK: - Upcoming Service Row
struct UpcomingServiceRow: View {
    let upcoming: UpcomingService
    let currentMileage: Int
    
    private var milesUntil: Int {
        upcoming.targetMileage - currentMileage
    }
    
    private var status: DashboardView.Status {
        if milesUntil < 0 {
            return .overdue
        } else if milesUntil < 500 {
            return .dueSoon
        } else {
            return .good
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: upcoming.serviceType.iconName)
                .foregroundColor(upcoming.serviceType.color)
                .frame(width: 24)
            
            Text(upcoming.serviceType.displayName)
                .font(.caption)
            
            Spacer()
            
            if milesUntil < 0 {
                Text("Overdue \(-milesUntil) mi")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("\(milesUntil) mi")
                    .font(.caption)
                    .foregroundColor(status.color)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Empty Dashboard View
struct EmptyDashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Vehicles")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add vehicles to see maintenance status on the dashboard")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

#Preview {
    DashboardView(selectedVehicle: nil)
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
