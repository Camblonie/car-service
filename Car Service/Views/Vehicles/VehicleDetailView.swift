//
//  VehicleDetailView.swift
//  Car Service
//
//  Detail view for a single vehicle showing specs and service history summary
//

import SwiftUI
import SwiftData

struct VehicleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vehicle: Vehicle
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    
    // Get service records sorted by mileage
    private var serviceRecords: [ServiceRecord] {
        vehicle.services?.sorted(by: { $0.mileage > $1.mileage }) ?? []
    }
    
    var body: some View {
        List {
            // Vehicle Header with Photos
            Section {
                VStack(spacing: 16) {
                    // Photo Gallery
                    if let photos = vehicle.photos, !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photos) { photo in
                                    if let image = photo.image {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 200, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        // Placeholder when no photos
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 150)
                            .overlay(
                                VStack {
                                    Image(systemName: "car.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    Text("No Photos")
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    // Vehicle Name
                    Text(vehicle.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // VIN if available
                    if let vin = vehicle.vin, !vin.isEmpty {
                        Text("VIN: \(vin)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // Current Mileage
            Section("Current Mileage") {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("\(vehicle.currentMileage) miles")
                        .font(.title3)
                }
                .padding(.vertical, 4)
            }
            
            // Oil Change Status
            Section("Oil Change Status") {
                if let nextMileage = vehicle.nextOilChangeMileage,
                   let milesUntil = vehicle.milesUntilOilChange {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(milesUntil < 500 ? .red : .green)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            if milesUntil <= 0 {
                                Text("OVERDUE by \(-milesUntil) miles")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            } else {
                                Text("\(milesUntil) miles remaining")
                                    .font(.headline)
                                    .foregroundColor(milesUntil < 500 ? .orange : .green)
                            }
                            Text("Next change at \(nextMileage) miles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Text("No oil change recorded yet")
                        .foregroundColor(.secondary)
                }
                
                // Oil Specs Quick Reference
                VStack(alignment: .leading, spacing: 8) {
                    Text("Oil Specifications")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    HStack {
                        Text("Weight:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(vehicle.oilWeight.isEmpty ? "Not set" : vehicle.oilWeight)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Quantity:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(vehicle.oilQuantity.isEmpty ? "Not set" : vehicle.oilQuantity)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Filter Part #:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(vehicle.oilFilterPartNumber.isEmpty ? "Not set" : vehicle.oilFilterPartNumber)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Recent Service History
            Section("Recent Service History") {
                if serviceRecords.isEmpty {
                    Text("No service records yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(serviceRecords.prefix(5)) { record in
                        ServiceRecordRow(record: record)
                    }
                    
                    if serviceRecords.count > 5 {
                        Text("+ \(serviceRecords.count - 5) more records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            
            // Upcoming Maintenance Button
            Section {
                NavigationLink {
                    UpcomingServiceView(vehicle: vehicle)
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                        Text("Upcoming Maintenance")
                        Spacer()
                        if let upcomingCount = vehicle.upcomingServices?.filter({ !$0.isCompleted }).count, upcomingCount > 0 {
                            Text("\(upcomingCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Actions
            Section {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Vehicle", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Vehicle", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingEditSheet) {
            AddEditVehicleView(vehicle: vehicle)
        }
        .alert("Delete Vehicle?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteVehicle()
            }
        } message: {
            Text("This will permanently delete \(vehicle.displayName) and all its service records. This action cannot be undone.")
        }
    }
    
    // Delete the vehicle
    private func deleteVehicle() {
        modelContext.delete(vehicle)
        dismiss()
    }
}

// MARK: - Service Record Row
struct ServiceRecordRow: View {
    let record: ServiceRecord
    
    var body: some View {
        HStack {
            // Service type icon
            ZStack {
                Circle()
                    .fill(record.serviceType.color.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: record.serviceType.iconName)
                    .foregroundColor(record.serviceType.color)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.serviceType.displayName)
                    .font(.headline)
                
                HStack {
                    Text("\(record.mileage) mi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(record.date, format: .dateTime.month().day().year())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let cost = record.cost {
                Text("$\(cost, format: .number.precision(.fractionLength(2)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        VehicleDetailView(vehicle: Vehicle(
            make: "Toyota",
            model: "Camry",
            year: 2020,
            vin: "ABC123456789",
            currentMileage: 45000,
            oilChangeInterval: 5000,
            oilWeight: "5W-30",
            oilQuantity: "5.5 quarts",
            oilFilterPartNumber: "PH7317"
        ))
    }
    .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
