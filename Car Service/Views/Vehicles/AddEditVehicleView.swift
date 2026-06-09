//
//  AddEditVehicleView.swift
//  Car Service
//
//  Modal view for adding or editing a vehicle
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddEditVehicleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let vehicle: Vehicle?
    
    @State private var make = ""
    @State private var model = ""
    @State private var year = ""
    @State private var vin = ""
    @State private var licensePlate = ""
    @State private var currentMileage = ""
    @State private var oilChangeInterval = "5000"
    @State private var oilWeight = ""
    @State private var oilQuantity = ""
    @State private var oilFilterPartNumber = ""
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photos: [VehiclePhoto] = []
    
    private var isEditing: Bool { vehicle != nil }
    private var isValid: Bool {
        !make.isEmpty && !model.isEmpty && !year.isEmpty && Int(year) != nil
    }
    
    init(vehicle: Vehicle?) {
        self.vehicle = vehicle
        if let vehicle = vehicle {
            _make = State(initialValue: vehicle.make)
            _model = State(initialValue: vehicle.model)
            _year = State(initialValue: String(vehicle.year))
            _vin = State(initialValue: vehicle.vin ?? "")
            _licensePlate = State(initialValue: vehicle.licensePlate ?? "")
            _currentMileage = State(initialValue: String(vehicle.currentMileage))
            _oilChangeInterval = State(initialValue: String(vehicle.oilChangeInterval))
            _oilWeight = State(initialValue: vehicle.oilWeight)
            _oilQuantity = State(initialValue: vehicle.oilQuantity)
            _oilFilterPartNumber = State(initialValue: vehicle.oilFilterPartNumber)
            _photos = State(initialValue: vehicle.photos ?? [])
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                vehicleInfoSection
                
                // Mileage Section
                Section("Mileage") {
                    TextField("Current Mileage", text: $currentMileage)
                        .keyboardType(.numberPad)
                }
                
                // Oil Change Section
                Section("Oil Change Specifications") {
                    TextField("Interval (miles)", text: $oilChangeInterval)
                        .keyboardType(.numberPad)
                    TextField("Oil Weight (e.g., 5W-30)", text: $oilWeight)
                    TextField("Oil Quantity (e.g., 5.5 quarts)", text: $oilQuantity)
                    TextField("Oil Filter Part Number", text: $oilFilterPartNumber)
                }
                
                // Photos Section
                Section("Photos") {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo.badge.plus")
                    }
                    
                    if !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photos) { photo in
                                    PhotoThumbnailView(
                                        photo: photo,
                                        isThumbnail: photo.isThumbnail,
                                        onSetThumbnail: { setThumbnail(photo) },
                                        onDelete: { deletePhoto(photo) }
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVehicle()
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                loadPhotos(from: newItems)
            }
        }
    }
    
    // Vehicle info form section extracted to reduce type-checker complexity
    @ViewBuilder
    private var vehicleInfoSection: some View {
        Section("Vehicle Information") {
            TextField("Make (e.g., Toyota)", text: $make)
            TextField("Model (e.g., Camry)", text: $model)
            TextField("Year", text: $year)
                .keyboardType(.numberPad)
            TextField("VIN (Optional)", text: $vin)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            TextField("License Plate (Optional)", text: $licensePlate)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
        }
    }
    
    // Load photos from selected items
    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let photo = VehiclePhoto(imageData: data)
                    await MainActor.run {
                        photos.append(photo)
                        // Set first photo as thumbnail if none exists
                        if photos.count == 1 {
                            photo.isThumbnail = true
                        }
                    }
                }
            }
            // Clear selection after loading
            selectedPhotoItems.removeAll()
        }
    }
    
    // Set photo as thumbnail
    private func setThumbnail(_ photo: VehiclePhoto) {
        for p in photos {
            p.isThumbnail = (p.id == photo.id)
        }
    }
    
    // Delete a photo
    private func deletePhoto(_ photo: VehiclePhoto) {
        photos.removeAll { $0.id == photo.id }
        modelContext.delete(photo)
    }
    
    // Save vehicle to database
    private func saveVehicle() {
        let mileage = Int(currentMileage) ?? 0
        let interval = Int(oilChangeInterval) ?? 5000
        let yearInt = Int(year) ?? Calendar.current.component(.year, from: Date())
        
        if let vehicle = vehicle {
            // Update existing vehicle
            vehicle.make = make
            vehicle.model = model
            vehicle.year = yearInt
            vehicle.vin = vin.isEmpty ? nil : vin
            vehicle.licensePlate = licensePlate.isEmpty ? nil : licensePlate
            vehicle.currentMileage = mileage
            vehicle.oilChangeInterval = interval
            vehicle.oilWeight = oilWeight
            vehicle.oilQuantity = oilQuantity
            vehicle.oilFilterPartNumber = oilFilterPartNumber
            
            // Associate photos
            for photo in photos {
                photo.vehicle = vehicle
            }
        } else {
            // Create new vehicle
            let newVehicle = Vehicle(
                make: make,
                model: model,
                year: yearInt,
                vin: vin.isEmpty ? nil : vin,
                licensePlate: licensePlate.isEmpty ? nil : licensePlate,
                currentMileage: mileage,
                oilChangeInterval: interval,
                oilWeight: oilWeight,
                oilQuantity: oilQuantity,
                oilFilterPartNumber: oilFilterPartNumber
            )
            
            // Associate photos
            for photo in photos {
                photo.vehicle = newVehicle
                modelContext.insert(photo)
            }
            
            modelContext.insert(newVehicle)
        }
        
        dismiss()
    }
}

// MARK: - Photo Thumbnail View
struct PhotoThumbnailView: View {
    let photo: VehiclePhoto
    let isThumbnail: Bool
    let onSetThumbnail: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isThumbnail ? Color.blue : Color.clear, lineWidth: 3)
                    )
            }
            
            HStack(spacing: 4) {
                Button(action: onSetThumbnail) {
                    Image(systemName: isThumbnail ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(isThumbnail ? .blue : .gray)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview {
    AddEditVehicleView(vehicle: nil)
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
