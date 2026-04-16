//
//  ServiceHistoryView.swift
//  Car Service
//
//  Displays service history for selected vehicle with filtering
//

import SwiftUI
import SwiftData

struct ServiceHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var allVehicles: [Vehicle]
    
    let selectedVehicle: Vehicle?
    
    @State private var selectedServiceType: ServiceType?
    @State private var showingAddService = false
    
    // Filtered service records
    private var serviceRecords: [ServiceRecord] {
        guard let vehicle = selectedVehicle else { return [] }
        let records = vehicle.services?.sorted(by: { $0.mileage > $1.mileage }) ?? []
        
        if let type = selectedServiceType {
            return records.filter { $0.serviceType == type }
        }
        return records
    }
    
    // Service counts by type for filter badges
    private var serviceTypeCounts: [(type: ServiceType, count: Int)] {
        guard let vehicle = selectedVehicle else { return [] }
        let records = vehicle.services ?? []
        
        return ServiceType.allCases.map { type in
            let count = records.filter { $0.serviceType == type }.count
            return (type, count)
        }.filter { $0.count > 0 }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if selectedVehicle == nil {
                    NoVehicleSelectedView()
                } else if serviceRecords.isEmpty {
                    EmptyServiceHistoryView(
                        vehicleName: selectedVehicle?.displayName ?? "",
                        showingAddService: $showingAddService
                    )
                } else {
                    serviceList
                }
            }
            .navigationTitle("Service History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddService = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(selectedVehicle == nil)
                }
            }
            .sheet(isPresented: $showingAddService) {
                if let vehicle = selectedVehicle {
                    AddServiceSheet(vehicle: vehicle)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
    
    // Service list with filters
    private var serviceList: some View {
        List {
            // Filter chips
            if !serviceTypeCounts.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // "All" filter button
                            FilterChip(
                                title: "All",
                                count: serviceRecords.count,
                                isSelected: selectedServiceType == nil,
                                color: .blue
                            ) {
                                selectedServiceType = nil
                            }
                            
                            // Type filter buttons
                            ForEach(serviceTypeCounts, id: \.type) { item in
                                FilterChip(
                                    title: item.type.displayName,
                                    count: item.count,
                                    isSelected: selectedServiceType == item.type,
                                    color: item.type.color
                                ) {
                                    selectedServiceType = (selectedServiceType == item.type) ? nil : item.type
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Service records
            Section("\(serviceRecords.count) Records") {
                ForEach(serviceRecords) { record in
                    ServiceRecordDetailRow(record: record)
                }
                .onDelete(perform: deleteRecords)
            }
        }
        .listStyle(.plain)
    }
    
    // Delete service records
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            let record = serviceRecords[index]
            modelContext.delete(record)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.3))
                    .clipShape(Capsule())
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Service Record Detail Row
struct ServiceRecordDetailRow: View {
    let record: ServiceRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Service type icon
                ZStack {
                    Circle()
                        .fill(record.serviceType.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: record.serviceType.iconName)
                        .foregroundColor(record.serviceType.color)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.serviceType.displayName)
                        .font(.headline)
                    
                    Text("\(record.mileage) miles")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.date, format: .dateTime.month().day().year())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let cost = record.cost {
                        Text("$\(cost, format: .number.precision(.fractionLength(2)))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            if let provider = record.provider, !provider.isEmpty {
                Label(provider, systemImage: "building.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State Views
struct NoVehicleSelectedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Vehicle Selected")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Go to the Vehicles tab to select a vehicle")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}

struct EmptyServiceHistoryView: View {
    let vehicleName: String
    @Binding var showingAddService: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Service Records")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first service record for \(vehicleName)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingAddService = true
            } label: {
                Label("Add Service Record", systemImage: "plus")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
    }
}

#Preview {
    ServiceHistoryView(selectedVehicle: nil)
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
