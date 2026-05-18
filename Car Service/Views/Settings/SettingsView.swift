//
//  SettingsView.swift
//  Car Service
//
//  Settings tab with import/export functionality
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var vehicles: [Vehicle]
    @Query private var services: [ServiceRecord]
    @Query private var photos: [VehiclePhoto]
    @Query private var upcoming: [UpcomingService]
    
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var showingImportConfirmation = false
    @State private var showingClearConfirmation = false
    @State private var importData: ExportData?
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    // Statistics
    private var vehicleCount: Int { vehicles.count }
    private var serviceCount: Int { services.count }
    private var photoCount: Int { photos.count }
    private var upcomingCount: Int { upcoming.filter { !$0.isCompleted }.count }
    
    var body: some View {
        NavigationStack {
            List {
                // Statistics Section
                Section("Statistics") {
                    StatRow(title: "Vehicles", value: vehicleCount, icon: "car.fill", color: .blue)
                    StatRow(title: "Service Records", value: serviceCount, icon: "list.bullet.clipboard", color: .green)
                    StatRow(title: "Photos", value: photoCount, icon: "photo", color: .purple)
                    StatRow(title: "Upcoming Services", value: upcomingCount, icon: "calendar.badge.clock", color: .orange)
                }
                
                // Backup & Restore Section
                Section("Backup & Restore") {
                    Button {
                        exportData(includePhotos: true)
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        exportData(includePhotos: false)
                    } label: {
                        Label("Export Without Photos", systemImage: "square.and.arrow.up")
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                }
                
                // Data Management Section
                Section("Data Management") {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
                
                // App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("iCloud Sync")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        // Export file presentation
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        // Import file picker
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        // Import confirmation dialog
        .alert("Import Data", isPresented: $showingImportConfirmation, presenting: importData) { data in
            Button("Cancel", role: .cancel) {}
            Button("Merge") {
                importData(data: data, replace: false)
            }
            Button("Replace All") {
                importData(data: data, replace: true)
            }
        } message: { data in
            Text("Found \(data.vehicles.count) vehicles and \(data.serviceRecords.count) service records. Would you like to merge with existing data or replace all data?")
        }
        // Clear confirmation
        .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all vehicles, service records, and photos. This action cannot be undone.")
        }
        // Alert for messages
        .alert("Car Service", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Export Functionality
    
    private func exportData(includePhotos: Bool) {
        // Show loading indicator or perform on background thread
        Task {
            do {
                let exportData = ExportData(
                    vehicles: vehicles.map { VehicleExport(from: $0, includePhotos: includePhotos) },
                    serviceRecords: services.map { ServiceRecordExport(from: $0) },
                    upcomingServices: upcoming.map { UpcomingServiceExport(from: $0) },
                    exportDate: Date(),
                    version: "1.0"
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                
                let data = try encoder.encode(exportData)
                
                // Save to temporary directory
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("CarServiceBackup_\(Date().timeIntervalSince1970)")
                    .appendingPathExtension("json")
                
                try data.write(to: tempURL)
                
                await MainActor.run {
                    shareItems = [tempURL]
                    showingShareSheet = true
                }
                
            } catch {
                await MainActor.run {
                    alertMessage = "Export failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    // MARK: - Import Functionality
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing security scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = "Cannot access file"
                showingAlert = true
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let importedData = try decoder.decode(ExportData.self, from: data)
                
                importData = importedData
                showingImportConfirmation = true
                
            } catch {
                alertMessage = "Import failed: \(error.localizedDescription)"
                showingAlert = true
            }
            
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func importData(data: ExportData, replace: Bool) {
        if replace {
            // Delete all existing data
            clearAllData()
        }
        
        // Import vehicles first (to establish relationships)
        var vehicleMap: [UUID: Vehicle] = [:] // Map old IDs to new vehicles
        
        for vehicleExport in data.vehicles {
            let vehicle = Vehicle(
                make: vehicleExport.make,
                model: vehicleExport.model,
                year: vehicleExport.year,
                vin: vehicleExport.vin,
                currentMileage: vehicleExport.currentMileage,
                oilChangeInterval: vehicleExport.oilChangeInterval,
                oilWeight: vehicleExport.oilWeight,
                oilQuantity: vehicleExport.oilQuantity,
                oilFilterPartNumber: vehicleExport.oilFilterPartNumber,
                createdAt: vehicleExport.createdAt
            )
            
            modelContext.insert(vehicle)
            vehicleMap[vehicleExport.id] = vehicle
            
            // Import photos if included
            for photoExport in vehicleExport.photos {
                if let imageData = Data(base64Encoded: photoExport.imageData) {
                    let photo = VehiclePhoto(
                        imageData: imageData,
                        caption: photoExport.caption,
                        isThumbnail: photoExport.isThumbnail,
                        vehicle: vehicle,
                        createdAt: photoExport.createdAt
                    )
                    modelContext.insert(photo)
                }
            }
        }
        
        // Import service records
        for recordExport in data.serviceRecords {
            if let vehicle = vehicleMap[recordExport.vehicleId] {
                let record = ServiceRecord(
                    serviceType: ServiceType(rawValue: recordExport.serviceType) ?? .other,
                    mileage: recordExport.mileage,
                    date: recordExport.date,
                    notes: recordExport.notes,
                    provider: recordExport.provider,
                    cost: recordExport.cost,
                    vehicle: vehicle,
                    createdAt: recordExport.createdAt
                )
                modelContext.insert(record)
            }
        }
        
        // Import upcoming services
        for upcomingExport in data.upcomingServices {
            if let vehicle = vehicleMap[upcomingExport.vehicleId] {
                let upcomingService = UpcomingService(
                    serviceType: ServiceType(rawValue: upcomingExport.serviceType) ?? .other,
                    targetMileage: upcomingExport.targetMileage,
                    targetDate: upcomingExport.targetDate,
                    notes: upcomingExport.notes,
                    vehicle: vehicle,
                    createdAt: upcomingExport.createdAt
                )
                upcomingService.isCompleted = upcomingExport.isCompleted
                modelContext.insert(upcomingService)
            }
        }
        
        alertMessage = "Import completed successfully!"
        showingAlert = true
    }
    
    // MARK: - Clear All Data
    
    private func clearAllData() {
        for vehicle in vehicles {
            modelContext.delete(vehicle)
        }
        // SwiftData will cascade delete related records
    }
    
    // App version string
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("\(value)")
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export Data Structures

struct ExportData: Codable {
    let vehicles: [VehicleExport]
    let serviceRecords: [ServiceRecordExport]
    let upcomingServices: [UpcomingServiceExport]
    let exportDate: Date
    let version: String
}

struct VehicleExport: Codable {
    let id: UUID
    let make: String
    let model: String
    let year: Int
    let vin: String?
    let currentMileage: Int
    let oilChangeInterval: Int
    let oilWeight: String
    let oilQuantity: String
    let oilFilterPartNumber: String
    let createdAt: Date
    let photos: [VehiclePhotoExport]
    
    init(from vehicle: Vehicle, includePhotos: Bool) {
        self.id = vehicle.id
        self.make = vehicle.make
        self.model = vehicle.model
        self.year = vehicle.year
        self.vin = vehicle.vin
        self.currentMileage = vehicle.currentMileage
        self.oilChangeInterval = vehicle.oilChangeInterval
        self.oilWeight = vehicle.oilWeight
        self.oilQuantity = vehicle.oilQuantity
        self.oilFilterPartNumber = vehicle.oilFilterPartNumber
        self.createdAt = vehicle.createdAt
        
        if includePhotos {
            self.photos = (vehicle.photos ?? []).map { VehiclePhotoExport(from: $0) }
        } else {
            self.photos = []
        }
    }
}

struct VehiclePhotoExport: Codable {
    let id: UUID
    let imageData: String // Base64 encoded
    let caption: String?
    let isThumbnail: Bool
    let createdAt: Date
    
    init(from photo: VehiclePhoto) {
        self.id = photo.id
        self.imageData = photo.imageData.base64EncodedString()
        self.caption = photo.caption
        self.isThumbnail = photo.isThumbnail
        self.createdAt = photo.createdAt
    }
}

struct ServiceRecordExport: Codable {
    let id: UUID
    let vehicleId: UUID
    let serviceType: String
    let mileage: Int
    let date: Date
    let notes: String
    let provider: String?
    let cost: Decimal?
    let createdAt: Date
    
    init(from record: ServiceRecord) {
        self.id = record.id
        self.vehicleId = record.vehicle?.id ?? UUID()
        self.serviceType = record.serviceTypeRaw
        self.mileage = record.mileage
        self.date = record.date
        self.notes = record.notes
        self.provider = record.provider
        self.cost = record.cost
        self.createdAt = record.createdAt
    }
}

struct UpcomingServiceExport: Codable {
    let id: UUID
    let vehicleId: UUID
    let serviceType: String
    let targetMileage: Int
    let targetDate: Date?
    let notes: String
    let isCompleted: Bool
    let createdAt: Date
    
    init(from upcoming: UpcomingService) {
        self.id = upcoming.id
        self.vehicleId = upcoming.vehicle?.id ?? UUID()
        self.serviceType = upcoming.serviceTypeRaw
        self.targetMileage = upcoming.targetMileage
        self.targetDate = upcoming.targetDate
        self.notes = upcoming.notes
        self.isCompleted = upcoming.isCompleted
        self.createdAt = upcoming.createdAt
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
