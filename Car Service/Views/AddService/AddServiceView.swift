//
//  AddServiceView.swift
//  Car Service
//
//  Tab view for quickly adding new service records with oil change reference
//

import SwiftUI
import SwiftData

struct AddServiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var allVehicles: [Vehicle]
    
    let selectedVehicle: Vehicle?
    
    @State private var selectedServiceType: ServiceType = .oilChange
    @State private var mileage = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var provider = ""
    @State private var cost = ""
    @State private var showingConfirmation = false
    
    // Check if oil change is selected
    private var isOilChange: Bool {
        selectedServiceType == .oilChange
    }
    
    // Check if form is valid
    private var isValid: Bool {
        guard let vehicle = selectedVehicle else { return false }
        guard let mileageInt = Int(mileage), mileageInt >= 0 else { return false }
        return mileageInt >= vehicle.currentMileage
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if selectedVehicle == nil {
                    NoVehicleSelectedView()
                } else {
                    addServiceForm
                }
            }
            .navigationTitle("Add Service")
        }
    }
    
    // Main form
    private var addServiceForm: some View {
        Form {
            // Vehicle Info Header
            Section {
                HStack {
                    Text("Vehicle:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(selectedVehicle?.displayName ?? "")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Current Mileage:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(selectedVehicle?.currentMileage ?? 0) mi")
                        .fontWeight(.medium)
                }
            }
            
            // Service Type
            Section("Service Type") {
                Picker("Service", selection: $selectedServiceType) {
                    ForEach(ServiceType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.iconName)
                                .foregroundColor(type.color)
                            Text(type.displayName)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            
            // Oil Change Reference Card (only shown when oil change selected)
            if isOilChange, let vehicle = selectedVehicle {
                Section("Oil Change Reference") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("Oil Specifications")
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Weight:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(vehicle.oilWeight.isEmpty ? "Not set" : vehicle.oilWeight)
                                .fontWeight(.semibold)
                                .foregroundColor(vehicle.oilWeight.isEmpty ? .red : .primary)
                        }
                        
                        HStack {
                            Text("Quantity:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(vehicle.oilQuantity.isEmpty ? "Not set" : vehicle.oilQuantity)
                                .fontWeight(.semibold)
                                .foregroundColor(vehicle.oilQuantity.isEmpty ? .red : .primary)
                        }
                        
                        HStack {
                            Text("Filter Part #:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(vehicle.oilFilterPartNumber.isEmpty ? "Not set" : vehicle.oilFilterPartNumber)
                                .fontWeight(.semibold)
                                .foregroundColor(vehicle.oilFilterPartNumber.isEmpty ? .red : .primary)
                        }
                        
                        if vehicle.oilWeight.isEmpty || vehicle.oilQuantity.isEmpty || vehicle.oilFilterPartNumber.isEmpty {
                            Text("⚠️ Update vehicle details to add missing oil specifications")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Service Details
            Section("Service Details") {
                TextField("Service Mileage", text: $mileage)
                    .keyboardType(.numberPad)
                
                DatePicker("Date", selection: $date, displayedComponents: .date)
                
                TextField("Service Provider (Optional)", text: $provider)
                
                TextField("Cost (Optional)", text: $cost)
                    .keyboardType(.decimalPad)
                
                TextField("Notes (Optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            // Save Button
            Section {
                Button(action: saveService) {
                    HStack {
                        Spacer()
                        Label("Save Service Record", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!isValid)
                .foregroundColor(isValid ? .blue : .gray)
            }
        }
        .alert("Service Record Saved", isPresented: $showingConfirmation) {
            Button("OK") {
                resetForm()
            }
        } message: {
            Text("The service record has been saved successfully.")
        }
    }
    
    // Save the service record
    private func saveService() {
        guard let vehicle = selectedVehicle else { return }
        guard let mileageInt = Int(mileage) else { return }
        
        let costDecimal = Decimal(string: cost)
        
        let serviceRecord = ServiceRecord(
            serviceType: selectedServiceType,
            mileage: mileageInt,
            date: date,
            notes: notes,
            provider: provider.isEmpty ? nil : provider,
            cost: costDecimal,
            vehicle: vehicle
        )
        
        // Update vehicle's current mileage if this service has higher mileage
        if mileageInt > vehicle.currentMileage {
            vehicle.currentMileage = mileageInt
        }
        
        modelContext.insert(serviceRecord)
        showingConfirmation = true
    }
    
    // Reset form after saving
    private func resetForm() {
        selectedServiceType = .oilChange
        mileage = ""
        date = Date()
        notes = ""
        provider = ""
        cost = ""
    }
}

// MARK: - Add Service Sheet (for modal presentation)
struct AddServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    
    @State private var selectedServiceType: ServiceType = .oilChange
    @State private var mileage = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var provider = ""
    @State private var cost = ""
    
    private var isOilChange: Bool {
        selectedServiceType == .oilChange
    }
    
    private var isValid: Bool {
        guard let mileageInt = Int(mileage), mileageInt >= 0 else { return false }
        return mileageInt >= vehicle.currentMileage
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Oil Change Reference Card
                if isOilChange {
                    Section("Oil Change Reference") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                Text("Oil Specifications")
                                    .font(.headline)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Weight:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vehicle.oilWeight.isEmpty ? "Not set" : vehicle.oilWeight)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Quantity:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vehicle.oilQuantity.isEmpty ? "Not set" : vehicle.oilQuantity)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Filter Part #:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vehicle.oilFilterPartNumber.isEmpty ? "Not set" : vehicle.oilFilterPartNumber)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Service Type
                Section("Service Type") {
                    Picker("Service", selection: $selectedServiceType) {
                        ForEach(ServiceType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.iconName)
                                    .foregroundColor(type.color)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Service Details
                Section("Service Details") {
                    TextField("Service Mileage (Current: \(vehicle.currentMileage))", text: $mileage)
                        .keyboardType(.numberPad)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    TextField("Service Provider (Optional)", text: $provider)
                    
                    TextField("Cost (Optional)", text: $cost)
                        .keyboardType(.decimalPad)
                    
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveService()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveService() {
        guard let mileageInt = Int(mileage) else { return }
        
        let costDecimal = Decimal(string: cost)
        
        let serviceRecord = ServiceRecord(
            serviceType: selectedServiceType,
            mileage: mileageInt,
            date: date,
            notes: notes,
            provider: provider.isEmpty ? nil : provider,
            cost: costDecimal,
            vehicle: vehicle
        )
        
        if mileageInt > vehicle.currentMileage {
            vehicle.currentMileage = mileageInt
        }
        
        dismiss()
    }
}

#Preview {
    AddServiceView(selectedVehicle: nil)
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
