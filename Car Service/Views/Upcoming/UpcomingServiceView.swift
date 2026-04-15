//
//  UpcomingServiceView.swift
//  Car Service
//
//  View for managing upcoming/planned maintenance
//

import SwiftUI
import SwiftData

struct UpcomingServiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vehicle: Vehicle
    
    @State private var showingAddSheet = false
    @State private var serviceToComplete: UpcomingService?
    @State private var showingCompleteConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var serviceToDelete: UpcomingService?
    
    // Filtered upcoming services
    private var upcomingServices: [UpcomingService] {
        vehicle.upcomingServices?
            .sorted { $0.targetMileage < $1.targetMileage } ?? []
    }
    
    private var incompleteServices: [UpcomingService] {
        upcomingServices.filter { !$0.isCompleted }
    }
    
    private var completedServices: [UpcomingService] {
        upcomingServices.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if incompleteServices.isEmpty && completedServices.isEmpty {
                    Section {
                        Text("No upcoming maintenance planned")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
                
                // Incomplete Services
                if !incompleteServices.isEmpty {
                    Section("Upcoming Maintenance") {
                        ForEach(incompleteServices) { upcoming in
                            UpcomingServiceRow(
                                upcoming: upcoming,
                                currentMileage: vehicle.currentMileage,
                                onComplete: { serviceToComplete = upcoming; showingCompleteConfirmation = true },
                                onDelete: { serviceToDelete = upcoming; showingDeleteConfirmation = true }
                            )
                        }
                    }
                }
                
                // Completed Services (collapsed by default)
                if !completedServices.isEmpty {
                    Section("Completed") {
                        ForEach(completedServices) { upcoming in
                            CompletedServiceRow(upcoming: upcoming)
                        }
                    }
                }
            }
            .navigationTitle("Upcoming Maintenance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddUpcomingServiceSheet(vehicle: vehicle)
            }
            .alert("Mark as Complete?", isPresented: $showingCompleteConfirmation, presenting: serviceToComplete) { service in
                Button("Cancel", role: .cancel) {}
                Button("Complete") {
                    completeService(service)
                }
            } message: { service in
                Text("This will mark the \(service.serviceType.displayName) as completed and create a service record. The vehicle's current mileage will be recorded.")
            }
            .alert("Delete Service?", isPresented: $showingDeleteConfirmation, presenting: serviceToDelete) { service in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteService(service)
                }
            } message: { service in
                Text("Are you sure you want to delete this upcoming service?")
            }
        }
    }
    
    // Complete the service and create a record
    private func completeService(_ service: UpcomingService) {
        // Create service record
        let record = ServiceRecord(
            serviceType: service.serviceType,
            mileage: vehicle.currentMileage,
            date: Date(),
            notes: "Completed from upcoming: \(service.notes)",
            vehicle: vehicle
        )
        modelContext.insert(record)
        
        // Mark upcoming as completed
        service.isCompleted = true
    }
    
    // Delete the service
    private func deleteService(_ service: UpcomingService) {
        modelContext.delete(service)
    }
}

// MARK: - Upcoming Service Row
struct UpcomingServiceRow: View {
    let upcoming: UpcomingService
    let currentMileage: Int
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    private var milesUntil: Int {
        upcoming.targetMileage - currentMileage
    }
    
    private var statusColor: Color {
        if milesUntil < 0 {
            return .red
        } else if milesUntil < 500 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(upcoming.serviceType.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: upcoming.serviceType.iconName)
                        .foregroundColor(upcoming.serviceType.color)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(upcoming.serviceType.displayName)
                        .font(.headline)
                    
                    HStack {
                        if milesUntil < 0 {
                            Text("Overdue by \(-milesUntil) mi")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("\(milesUntil) mi remaining")
                                .font(.caption)
                                .foregroundColor(statusColor)
                        }
                        
                        if let targetDate = upcoming.targetDate {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(targetDate, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onComplete) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            
            if !upcoming.notes.isEmpty {
                Text(upcoming.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("Target: \(upcoming.targetMileage) mi", systemImage: "flag.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Completed Service Row
struct CompletedServiceRow: View {
    let upcoming: UpcomingService
    
    var body: some View {
        HStack {
            Image(systemName: upcoming.serviceType.iconName)
                .foregroundColor(upcoming.serviceType.color)
                .opacity(0.6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(upcoming.serviceType.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Completed")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Text("Target: \(upcoming.targetMileage) mi")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .opacity(0.6)
    }
}

// MARK: - Add Upcoming Service Sheet
struct AddUpcomingServiceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vehicle: Vehicle
    
    @State private var selectedServiceType: ServiceType = .oilChange
    @State private var targetMileage = ""
    @State private var targetDate: Date?
    @State private var notes = ""
    @State private var showingDatePicker = false
    
    private var isValid: Bool {
        guard let mileage = Int(targetMileage) else { return false }
        return mileage > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
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
                
                Section("Target") {
                    TextField("Target Mileage", text: $targetMileage)
                        .keyboardType(.numberPad)
                    
                    HStack {
                        Text("Target Date (Optional)")
                        Spacer()
                        if let date = targetDate {
                            Text(date, format: .dateTime.month().day().year())
                                .foregroundColor(.primary)
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingDatePicker = true
                    }
                }
                
                Section("Notes") {
                    TextField("Notes (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Upcoming Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveUpcomingService()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $targetDate, isPresented: $showingDatePicker)
            }
        }
    }
    
    private func saveUpcomingService() {
        guard let mileage = Int(targetMileage) else { return }
        
        let upcomingService = UpcomingService(
            serviceType: selectedServiceType,
            targetMileage: mileage,
            targetDate: targetDate,
            notes: notes,
            vehicle: vehicle
        )
        
        modelContext.insert(upcomingService)
        dismiss()
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date?
    @Binding var isPresented: Bool
    
    @State private var tempDate = Date()
    
    var body: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: $tempDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        selectedDate = nil
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDate = tempDate
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        UpcomingServiceView(vehicle: Vehicle(
            make: "Toyota",
            model: "Camry",
            year: 2020
        ))
    }
    .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
