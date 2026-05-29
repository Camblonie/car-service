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
    
    @State private var showingAddVehicle = false
    @State private var showingEditVehicle = false
    @State private var vehicleToEdit: Vehicle?
    @State private var searchText = ""
    @State private var vehicleToDelete: Vehicle?
    @State private var showingDeleteConfirmation = false
    @State private var showingMileageUpdate = false
    @State private var vehicleToUpdateMileage: Vehicle?
    @State private var newMileage = ""
    
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
            .sheet(isPresented: $showingEditVehicle) {
                if let vehicle = vehicleToEdit {
                    AddEditVehicleView(vehicle: vehicle)
                }
            }
            .alert("Delete Vehicle?", isPresented: $showingDeleteConfirmation, presenting: vehicleToDelete) { vehicle in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteVehicle(vehicle)
                }
            } message: { vehicle in
                Text("This will permanently delete \(vehicle.displayName) and all its service records. This action cannot be undone.")
            }
            .sheet(isPresented: $showingMileageUpdate) {
                if let vehicle = vehicleToUpdateMileage {
                    MileageUpdateSheet(vehicle: vehicle, newMileage: $newMileage, isPresented: $showingMileageUpdate)
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search vehicles")
    }
    
    // Vehicle list view
    private var vehicleList: some View {
        List {
            ForEach(filteredVehicles) { vehicle in
                NavigationLink(value: vehicle) {
                    VehicleCard(
                        vehicle: vehicle,
                        onMileageUpdate: {
                            vehicleToUpdateMileage = vehicle
                            newMileage = "\(vehicle.currentMileage)"
                            showingMileageUpdate = true
                        }
                    )
                }
                .swipeActions(edge: .leading) {
                    Button {
                        vehicleToEdit = vehicle
                        showingEditVehicle = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                    
                    Button {
                        vehicleToUpdateMileage = vehicle
                        newMileage = "\(vehicle.currentMileage)"
                        showingMileageUpdate = true
                    } label: {
                        Label("Mileage", systemImage: "speedometer")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        vehicleToDelete = vehicle
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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
    }
}

// MARK: - Vehicle Card
struct VehicleCard: View {
    let vehicle: Vehicle
    let onMileageUpdate: () -> Void
    
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
                
                if let licensePlate = vehicle.licensePlate, !licensePlate.isEmpty {
                    Text("Plate: \(licensePlate)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Quick mileage update button
            Button(action: onMileageUpdate) {
                Image(systemName: "speedometer")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Mileage Update Sheet
struct MileageUpdateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    @Binding var newMileage: String
    @Binding var isPresented: Bool
    
    private var isValid: Bool {
        guard let mileageInt = Int(newMileage), mileageInt >= 0 else { return false }
        return mileageInt >= vehicle.currentMileage
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Update mileage for \(vehicle.displayName)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Section("Current Mileage") {
                    Text("\(vehicle.currentMileage) mi")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Section("New Mileage") {
                    TextField("Enter new mileage", text: $newMileage)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button(action: saveMileage) {
                        HStack {
                            Spacer()
                            Label("Update Mileage", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                    .foregroundColor(isValid ? .blue : .gray)
                }
            }
            .navigationTitle("Update Mileage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMileage()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveMileage() {
        guard let mileageInt = Int(newMileage), mileageInt >= vehicle.currentMileage else { return }
        
        vehicle.currentMileage = mileageInt
        dismiss()
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
    VehicleListView()
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}

#Preview("Vehicle Card") {
    VStack {
        VehicleCard(
            vehicle: Vehicle(make: "Toyota", model: "Camry", year: 2020, currentMileage: 50000),
            onMileageUpdate: {},
            onLongPress: {}
        )
        VehicleCard(
            vehicle: Vehicle(make: "Honda", model: "Civic", year: 2021, currentMileage: 30000),
            onMileageUpdate: {},
            onLongPress: {}
        )
    }
    .padding()
}
