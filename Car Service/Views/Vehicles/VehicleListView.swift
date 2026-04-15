//
//  VehicleListView.swift
//  Car Service
//
//  Displays list of all vehicles with search and add functionality
//

import SwiftUI
import SwiftData

struct VehicleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var vehicles: [Vehicle]
    
    @Binding var selectedVehicle: Vehicle?
    @State private var showingAddVehicle = false
    @State private var searchText = ""
    @State private var vehicleToDelete: Vehicle?
    @State private var showingDeleteConfirmation = false
    
    // Filtered vehicles based on search
    private var filteredVehicles: [Vehicle] {
        if searchText.isEmpty {
            return vehicles
        }
        return vehicles.filter { vehicle in
            vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
            (vehicle.vin?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    EmptyVehicleView(showingAddVehicle: $showingAddVehicle)
                } else {
                    vehicleList
                }
            }
            .navigationTitle("My Vehicles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddEditVehicleView(vehicle: nil)
            }
            .alert("Delete Vehicle?", isPresented: $showingDeleteConfirmation, presenting: vehicleToDelete) { vehicle in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteVehicle(vehicle)
                }
            } message: { vehicle in
                Text("This will permanently delete \(vehicle.displayName) and all its service records. This action cannot be undone.")
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search vehicles")
    }
    
    // Vehicle list view
    private var vehicleList: some View {
        List {
            ForEach(filteredVehicles) { vehicle in
                NavigationLink(value: vehicle) {
                    VehicleCard(vehicle: vehicle, isSelected: selectedVehicle?.id == vehicle.id)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        vehicleToDelete = vehicle
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onTapGesture {
                    selectedVehicle = vehicle
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Vehicle.self) { vehicle in
            VehicleDetailView(vehicle: vehicle)
        }
    }
    
    // Delete vehicle and all related data
    private func deleteVehicle(_ vehicle: Vehicle) {
        modelContext.delete(vehicle)
        if selectedVehicle?.id == vehicle.id {
            selectedVehicle = vehicles.first { $0.id != vehicle.id }
        }
    }
}

// MARK: - Vehicle Card
struct VehicleCard: View {
    let vehicle: Vehicle
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnail = vehicle.thumbnailPhoto,
               let image = thumbnail.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // Default placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "car.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.headline)
                
                HStack {
                    Label("\(vehicle.currentMileage) mi", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let milesUntil = vehicle.milesUntilOilChange {
                        Text("•")
                            .foregroundColor(.secondary)
                        Label("\(milesUntil) mi to oil change", systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundColor(milesUntil < 500 ? .red : .secondary)
                    }
                }
                
                if let vin = vehicle.vin, !vin.isEmpty {
                    Text("VIN: \(vin)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State
struct EmptyVehicleView: View {
    @Binding var showingAddVehicle: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "car.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Vehicles")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first vehicle to start tracking maintenance")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingAddVehicle = true
            } label: {
                Label("Add Your First Vehicle", systemImage: "plus")
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
    VehicleListView(selectedVehicle: .constant(nil))
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
