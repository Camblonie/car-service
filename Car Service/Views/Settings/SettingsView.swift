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
    
    @State private var showingImportPicker = false
    @State private var showingImportConfirmation = false
    @State private var showingClearConfirmation = false
    @State private var importData: ExportData?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingExportFormatPicker = false
    @State private var exportIncludePhotos = true
    
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
                        exportIncludePhotos = true
                        showingExportFormatPicker = true
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        exportIncludePhotos = false
                        showingExportFormatPicker = true
                    } label: {
                        Label("Export Without Photos", systemImage: "square.and.arrow.up.on.square")
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
        // Trigger share sheet presentation when ready
        .onChange(of: showingShareSheet) { _, newValue in
            if newValue {
                presentShareSheet()
            }
        }
        // Import file picker
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json, .commaSeparatedText],
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
        // Export format picker
        .sheet(isPresented: $showingExportFormatPicker) {
            ExportFormatPicker(
                includePhotos: exportIncludePhotos,
                onJSONSelected: {
                    exportData(format: .json, includePhotos: exportIncludePhotos)
                },
                onCSVSelected: {
                    exportData(format: .csv, includePhotos: exportIncludePhotos)
                }
            )
        }
    }
    
    // MARK: - Share Sheet Presentation
    
    // Present UIActivityViewController from the key window's root view controller
    private func presentShareSheet() {
        guard !shareItems.isEmpty,
              let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow),
              var topController = window.rootViewController else {
            showingShareSheet = false
            return
        }
        
        // Walk up the chain to find the topmost presented view controller
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        let activityVC = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                showingShareSheet = false
            }
        }
        
        topController.present(activityVC, animated: true)
    }
    
    // MARK: - Export Functionality
    
    enum ExportFormat {
        case json
        case csv
    }
    
    private func exportData(format: ExportFormat, includePhotos: Bool) {
        // Show loading indicator or perform on background thread
        Task {
            do {
                let data: Data
                let fileName: String
                
                switch format {
                case .json:
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
                    data = try encoder.encode(exportData)
                    fileName = "CarServiceBackup_\(Date().timeIntervalSince1970).json"
                    
                case .csv:
                    data = try generateCSV(includePhotos: includePhotos)
                    fileName = "CarServiceExport_\(Date().timeIntervalSince1970).csv"
                }
                
                // Save to temporary directory
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)
                
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
    
    // Generate CSV data from vehicles and services
    private func generateCSV(includePhotos: Bool) throws -> Data {
        var csvLines: [String] = []
        
        // CSV Header
        csvLines.append("Type,Vehicle Name,Make,Model,Year,VIN,Current Mileage,Service Type,Service Mileage,Service Date,Notes,Provider,Cost")
        
        // Add vehicle rows
        for vehicle in vehicles {
            csvLines.append("Vehicle,\(vehicle.displayName),\(vehicle.make),\(vehicle.model),\(vehicle.year),\(vehicle.vin ?? ""),\(vehicle.currentMileage),,,,,,")
        }
        
        // Add service record rows
        for service in services {
            let vehicleName = service.vehicle?.displayName ?? "Unknown"
            let costString = service.cost?.description ?? ""
            let dateString = ISO8601DateFormatter().string(from: service.date)
            
            csvLines.append("Service,\(vehicleName),\(service.vehicle?.make ?? ""),\(service.vehicle?.model ?? ""),\(service.vehicle?.year ?? 0),\(service.vehicle?.vin ?? ""),,\(service.serviceType.displayName),\(service.mileage),\(dateString),\"\(service.notes.replacingOccurrences(of: "\"", with: "\"\""))\",\(service.provider ?? ""),\(costString)")
        }
        
        let csvString = csvLines.joined(separator: "\n")
        guard let data = csvString.data(using: .utf8) else {
            throw NSError(domain: "CSVGeneration", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert CSV string to data"])
        }
        
        return data
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
                
                // Detect file type by extension or content
                let fileExtension = url.pathExtension.lowercased()
                
                if fileExtension == "csv" || fileExtension == "txt" {
                    // Parse CSV
                    let importedData = try parseCSV(data: data)
                    importData = importedData
                    showingImportConfirmation = true
                } else {
                    // Parse JSON
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let importedData = try decoder.decode(ExportData.self, from: data)
                    
                    importData = importedData
                    showingImportConfirmation = true
                }
                
            } catch {
                alertMessage = "Import failed: \(error.localizedDescription)"
                showingAlert = true
            }
            
        case .failure(let error):
            alertMessage = "Import failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // Parse CSV data into ExportData
    private func parseCSV(data: Data) throws -> ExportData {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVImport", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode CSV data"])
        }
        
        var lines = csvString.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            throw NSError(domain: "CSVImport", code: 0, userInfo: [NSLocalizedDescriptionKey: "CSV file is empty"])
        }
        
        // Remove header row
        let header = lines.removeFirst()
        
        var vehicles: [VehicleExport] = []
        var serviceRecords: [ServiceRecordExport] = []
        var vehicleMap: [String: VehicleExport] = [:] // Map vehicle name to export
        
        let dateFormatter = ISO8601DateFormatter()
        
        for line in lines {
            if line.isEmpty { continue }
            
            // Parse CSV line handling quoted fields
            let fields = parseCSVLine(line)
            guard fields.count >= 2 else { continue }
            
            let type = fields[0]
            
            if type == "Vehicle" && fields.count >= 7 {
                let vin = fields.count > 5 && !fields[5].isEmpty ? fields[5] : nil
                let vehicleExport = VehicleExport(
                    id: UUID(),
                    make: fields.count > 2 ? fields[2] : "",
                    model: fields.count > 3 ? fields[3] : "",
                    year: Int(fields.count > 4 ? fields[4] : "0") ?? 0,
                    vin: vin,
                    currentMileage: Int(fields.count > 6 ? fields[6] : "0") ?? 0,
                    oilChangeInterval: nil,
                    oilWeight: nil,
                    oilQuantity: nil,
                    oilFilterPartNumber: nil,
                    photos: [],
                    createdAt: nil
                )
                vehicles.append(vehicleExport)
                // Map by display name composed from year/make/model to match vehicle name in service rows
                let displayName = "\(vehicleExport.year) \(vehicleExport.make) \(vehicleExport.model)"
                vehicleMap[displayName] = vehicleExport
                
            } else if type == "Service" && fields.count >= 10 {
                let vehicleName = fields[1]
                let vehicleExport = vehicleMap[vehicleName]
                
                // Parse cost as Decimal
                let cost: Decimal?
                if fields.count > 12, !fields[12].isEmpty, let costDouble = Double(fields[12]) {
                    cost = Decimal(costDouble)
                } else {
                    cost = nil
                }
                
                let provider = fields.count > 11 && !fields[11].isEmpty ? fields[11] : nil
                
                let serviceRecordExport = ServiceRecordExport(
                    id: UUID(),
                    vehicleId: vehicleExport?.id ?? UUID(),
                    serviceType: fields.count > 7 ? fields[7] : "other",
                    mileage: Int(fields.count > 8 ? fields[8] : "0") ?? 0,
                    date: fields.count > 9 ? dateFormatter.date(from: fields[9]) ?? Date() : Date(),
                    notes: fields.count > 10 ? fields[10] : "",
                    provider: provider,
                    cost: cost,
                    createdAt: nil
                )
                serviceRecords.append(serviceRecordExport)
            }
        }
        
        return ExportData(
            vehicles: vehicles,
            serviceRecords: serviceRecords,
            upcomingServices: [],
            exportDate: Date(),
            version: "1.0"
        )
    }
    
    // Parse a single CSV line handling quoted fields
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
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
                oilChangeInterval: vehicleExport.oilChangeInterval ?? 5000,
                oilWeight: vehicleExport.oilWeight ?? "",
                oilQuantity: vehicleExport.oilQuantity ?? "",
                oilFilterPartNumber: vehicleExport.oilFilterPartNumber ?? "",
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

// MARK: - Export Format Picker
struct ExportFormatPicker: View {
    @Environment(\.dismiss) private var dismiss
    let includePhotos: Bool
    let onJSONSelected: () -> Void
    let onCSVSelected: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onJSONSelected()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("JSON Format")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button {
                        onCSVSelected()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "tablecells")
                                .foregroundColor(.green)
                            Text("CSV/Spreadsheet Format")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    Text("Export Format")
                } footer: {
                    Text(includePhotos 
                        ? "JSON preserves all data including photos. CSV is a spreadsheet-friendly format without photos." 
                        : "JSON preserves all data structure. CSV is a spreadsheet-friendly format for easy viewing in Excel or Numbers.")
                }
            }
            .navigationTitle("Choose Format")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
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
    let oilChangeInterval: Int?
    let oilWeight: String?
    let oilQuantity: String?
    let oilFilterPartNumber: String?
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
    
    // Initializer for CSV import
    init(id: UUID, make: String, model: String, year: Int, vin: String?, currentMileage: Int, oilChangeInterval: Int?, oilWeight: String?, oilQuantity: String?, oilFilterPartNumber: String?, photos: [VehiclePhotoExport], createdAt: Date?) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.currentMileage = currentMileage
        self.oilChangeInterval = oilChangeInterval
        self.oilWeight = oilWeight
        self.oilQuantity = oilQuantity
        self.oilFilterPartNumber = oilFilterPartNumber
        self.photos = photos
        self.createdAt = createdAt ?? Date()
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
    
    // Initializer for CSV import
    init(id: UUID, vehicleId: UUID, serviceType: String, mileage: Int, date: Date, notes: String, provider: String?, cost: Decimal?, createdAt: Date?) {
        self.id = id
        self.vehicleId = vehicleId
        self.serviceType = serviceType
        self.mileage = mileage
        self.date = date
        self.notes = notes
        self.provider = provider
        self.cost = cost
        self.createdAt = createdAt ?? Date()
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
