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
                        
                        HStack {
                            Text("Drain Bolt Size:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(vehicle.drainBoltSize.isEmpty ? "Not set" : vehicle.drainBoltSize)
                                .fontWeight(.semibold)
                                .foregroundColor(vehicle.drainBoltSize.isEmpty ? .red : .primary)
                        }
                        
                        if vehicle.oilWeight.isEmpty || vehicle.oilQuantity.isEmpty || vehicle.oilFilterPartNumber.isEmpty || vehicle.drainBoltSize.isEmpty {
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
                
                // Quick option to use the vehicle's recorded current mileage
                if let vehicle = selectedVehicle, mileage != String(vehicle.currentMileage) {
                    Button {
                        mileage = String(vehicle.currentMileage)
                    } label: {
                        HStack {
                            Spacer()
                            Label("Use Current Mileage (\(vehicle.currentMileage) mi)", systemImage: "speedometer")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                }
                
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
        .navigationTitle("Add Service")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
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
        
        // Strip time-of-day — store date as month/day/year only
        let dateOnly = Calendar.current.startOfDay(for: date)
        
        let serviceRecord = ServiceRecord(
            serviceType: selectedServiceType,
            mileage: mileageInt,
            date: dateOnly,
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
    
    // Dismiss keyboard
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Add Service Sheet (for modal presentation)
struct AddServiceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    let record: ServiceRecord?
    
    @State private var selectedServiceType: ServiceType
    @State private var mileage: String
    @State private var date: Date
    @State private var notes: String
    @State private var provider: String
    @State private var cost: String
    
    // True when an existing record is being edited instead of creating a new one
    private var isEditing: Bool { record != nil }
    
    private var isOilChange: Bool {
        selectedServiceType == .oilChange
    }
    
    private var isValid: Bool {
        guard let mileageInt = Int(mileage), mileageInt >= 0 else { return false }
        // Editing allows corrections, so only enforce minimum current mileage when adding
        return isEditing ? true : mileageInt >= vehicle.currentMileage
    }
    
    init(vehicle: Vehicle, record: ServiceRecord? = nil) {
        self.vehicle = vehicle
        self.record = record
        _selectedServiceType = State(initialValue: record?.serviceType ?? .oilChange)
        _mileage = State(initialValue: record.map { String($0.mileage) } ?? "")
        _date = State(initialValue: record?.date ?? Date())
        _notes = State(initialValue: record?.notes ?? "")
        _provider = State(initialValue: record?.provider ?? "")
        _cost = State(initialValue: record.flatMap { $0.cost }.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
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
                            
                            HStack {
                                Text("Drain Bolt Size:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vehicle.drainBoltSize.isEmpty ? "Not set" : vehicle.drainBoltSize)
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
                    TextField("Service Mileage", text: $mileage)
                        .keyboardType(.numberPad)
                    
                    // Quick option to use the vehicle's recorded current mileage
                    if mileage != String(vehicle.currentMileage) {
                        Button {
                            mileage = String(vehicle.currentMileage)
                        } label: {
                            HStack {
                                Spacer()
                                Label("Use Current Mileage (\(vehicle.currentMileage) mi)", systemImage: "speedometer")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    TextField("Service Provider (Optional)", text: $provider)
                    
                    TextField("Cost (Optional)", text: $cost)
                        .keyboardType(.decimalPad)
                    
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Service" : "Add Service")
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
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func saveService() {
        guard let mileageInt = Int(mileage) else { return }
        
        let costDecimal = Decimal(string: cost)
        
        // Strip time-of-day — store date as month/day/year only
        let dateOnly = Calendar.current.startOfDay(for: date)
        
        if let record = record {
            // Update the existing record with corrected values
            record.serviceTypeRaw = selectedServiceType.rawValue
            record.mileage = mileageInt
            record.date = dateOnly
            record.notes = notes
            record.provider = provider.isEmpty ? nil : provider
            record.cost = costDecimal
        } else {
            // Create and insert a new service record
            let serviceRecord = ServiceRecord(
                serviceType: selectedServiceType,
                mileage: mileageInt,
                date: dateOnly,
                notes: notes,
                provider: provider.isEmpty ? nil : provider,
                cost: costDecimal,
                vehicle: vehicle
            )
            modelContext.insert(serviceRecord)
        }
        
        // Keep the vehicle's current mileage in sync if the service mileage increased
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
