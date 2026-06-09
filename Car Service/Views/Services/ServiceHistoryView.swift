//
//  ServiceHistoryView.swift
//  Car Service
//
//  Displays service history — either all vehicles (global tab) or a single vehicle.
//  Pass `vehicle` to scope to one vehicle; omit for the global History tab.
//

import SwiftUI
import SwiftData

struct ServiceHistoryView: View {
    @Environment(\.modelContext) private var modelContext

    // Optional: scope to a single vehicle; nil = show all records
    var vehicle: Vehicle? = nil

    @Query(sort: \ServiceRecord.date, order: .reverse) private var allRecords: [ServiceRecord]

    @State private var searchText = ""
    @State private var selectedServiceType: ServiceType? = nil
    @State private var selectedVehicleID: UUID? = nil
    @State private var showingAddService = false

    // All unique vehicles that have service records (used for vehicle filter chips)
    @Query(sort: \Vehicle.make) private var allVehicles: [Vehicle]
    private var vehiclesWithRecords: [Vehicle] {
        allVehicles.filter { !($0.services?.isEmpty ?? true) }
    }

    // Records filtered by vehicle scope, vehicle chip, type chip, and search text
    private var filteredRecords: [ServiceRecord] {
        allRecords.filter { record in
            // Scope to passed-in vehicle (vehicle-detail mode)
            if let v = vehicle {
                guard record.vehicle?.id == v.id else { return false }
            }
            // Vehicle filter chip (global mode only)
            if vehicle == nil, let vid = selectedVehicleID {
                guard record.vehicle?.id == vid else { return false }
            }
            if let type = selectedServiceType {
                guard record.serviceType == type else { return false }
            }
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let matchesType = record.serviceType.displayName.lowercased().contains(q)
                let matchesVehicle = record.vehicle?.displayName.lowercased().contains(q) ?? false
                let matchesProvider = record.provider?.lowercased().contains(q) ?? false
                let matchesNotes = record.notes.lowercased().contains(q)
                guard matchesType || matchesVehicle || matchesProvider || matchesNotes else { return false }
            }
            return true
        }
    }

    // Records grouped by year, newest first
    private var recordsByYear: [(year: Int, records: [ServiceRecord])] {
        let grouped = Dictionary(grouping: filteredRecords) {
            Calendar.current.component(.year, from: $0.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (year: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
    }

    // Counts per type for filter chips (respects vehicle chip selection)
    private var serviceTypeCounts: [(type: ServiceType, count: Int)] {
        var base = vehicle.map { v in allRecords.filter { $0.vehicle?.id == v.id } } ?? allRecords
        if vehicle == nil, let vid = selectedVehicleID {
            base = base.filter { $0.vehicle?.id == vid }
        }
        return ServiceType.allCases.compactMap { type in
            let count = base.filter { $0.serviceType == type }.count
            return count > 0 ? (type, count) : nil
        }
    }

    // Record count per vehicle for vehicle chips
    private var vehicleCounts: [(vehicle: Vehicle, count: Int)] {
        vehiclesWithRecords.compactMap { v in
            let count = allRecords.filter { $0.vehicle?.id == v.id }.count
            return count > 0 ? (v, count) : nil
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Service Records" : "No Results",
                        systemImage: "list.bullet.clipboard",
                        description: Text(searchText.isEmpty
                            ? "Add your first service record to start tracking maintenance history."
                            : "Try a different search term or clear the filter.")
                    )
                } else {
                    List {
                        // Vehicle filter chips (global tab only)
                        if vehicle == nil && vehicleCounts.count > 1 {
                            Section {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        FilterChip(
                                            title: "All Vehicles",
                                            count: allRecords.count,
                                            isSelected: selectedVehicleID == nil,
                                            color: .indigo,
                                            showCount: false
                                        ) {
                                            selectedVehicleID = nil
                                            selectedServiceType = nil
                                        }
                                        ForEach(vehicleCounts, id: \.vehicle.id) { item in
                                            FilterChip(
                                                title: item.vehicle.displayName,
                                                count: item.count,
                                                isSelected: selectedVehicleID == item.vehicle.id,
                                                color: .indigo
                                            ) {
                                                selectedVehicleID = selectedVehicleID == item.vehicle.id ? nil : item.vehicle.id
                                                selectedServiceType = nil
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }

                        // Service type filter chips
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    FilterChip(
                                        title: "All Types",
                                        count: (vehicle.map { v in allRecords.filter { $0.vehicle?.id == v.id }.count } ?? allRecords.filter { vehicle == nil && selectedVehicleID == nil ? true : $0.vehicle?.id == selectedVehicleID }.count),
                                        isSelected: selectedServiceType == nil,
                                        color: .blue,
                                        showCount: false
                                    ) { selectedServiceType = nil }

                                    ForEach(serviceTypeCounts, id: \.type) { item in
                                        FilterChip(
                                            title: item.type.displayName,
                                            count: item.count,
                                            isSelected: selectedServiceType == item.type,
                                            color: item.type.color
                                        ) {
                                            selectedServiceType = selectedServiceType == item.type ? nil : item.type
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                        // Records grouped by year
                        ForEach(recordsByYear, id: \.year) { group in
                            Section("\(String(group.year)) Services") {
                                ForEach(group.records) { record in
                                    NavigationLink {
                                        ServiceRecordDetailView(record: record)
                                    } label: {
                                        ServiceRecordDetailRow(record: record, showVehicleName: vehicle == nil)
                                    }
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        modelContext.delete(group.records[index])
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(vehicle != nil ? "Service History" : "All Service Records")
            .searchable(text: $searchText, prompt: "Search records")
            .toolbar {
                if let v = vehicle {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAddService = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                    // Suppress unused warning
                    let _ = v
                }
            }
            .sheet(isPresented: $showingAddService) {
                if let v = vehicle {
                    AddServiceSheet(vehicle: v)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    var showCount: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if showCount {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Capsule())
                }
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
// Row used in the history list — optionally shows the vehicle name
struct ServiceRecordDetailRow: View {
    let record: ServiceRecord
    var showVehicleName: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Vehicle thumbnail (shown when available)
                if let thumbnail = record.vehicle?.thumbnailPhoto?.image {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Service type icon always shown
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

                    HStack(spacing: 4) {
                        if showVehicleName, let vehicleName = record.vehicle?.displayName {
                            Text(vehicleName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("·")
                                .foregroundColor(.secondary)
                        }
                        Text("\(record.mileage) mi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
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
                .font(.title2).fontWeight(.semibold)
            Text("Go to the Vehicles tab to select a vehicle")
                .font(.body).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
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
                .font(.title2).fontWeight(.semibold)
            Text("Add your first service record for \(vehicleName)")
                .font(.body).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Button {
                showingAddService = true
            } label: {
                Label("Add Service Record", systemImage: "plus")
                    .font(.headline).padding()
                    .background(Color.blue).foregroundColor(.white)
                    .cornerRadius(10)
            }
            Spacer()
        }
    }
}

#Preview {
    ServiceHistoryView()
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
