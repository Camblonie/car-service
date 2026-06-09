//
//  SettingsView.swift
//  Car Service
//
//  Settings tab with import/export functionality
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MessageUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vehicle.make) private var vehicles: [Vehicle]
    @Query private var services: [ServiceRecord]
    @Query private var photos: [VehiclePhoto]
    @Query private var upcoming: [UpcomingService]
    
    @State private var showingImportPicker = false
    @State private var showingImportConfirmation = false
    @State private var showingReplaceWarning = false
    @State private var pendingImportIsCSV = false
    @State private var showingClearConfirmation = false
    @State private var pendingImportData: ExportData?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingExportFormatPicker = false
    @State private var exportIncludePhotos = true
    @State private var showingMailCompose = false
    @State private var mailAttachmentURL: URL?
    
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
        .alert("Import Data", isPresented: $showingImportConfirmation, presenting: pendingImportData) { data in
            Button("Cancel", role: .cancel) {}
            Button("Merge") {
                importData(data: data, replace: false)
            }
            Button("Replace All", role: .destructive) {
                // Show image-loss warning only for CSV imports (JSON exports include photos)
                if pendingImportIsCSV {
                    showingReplaceWarning = true
                } else {
                    if let data = pendingImportData {
                        importData(data: data, replace: true)
                    }
                }
            }
        } message: { data in
            Text("Found \(data.vehicles.count) vehicles and \(data.serviceRecords.count) service records. Would you like to merge with existing data or replace all data?")
        }
        // Replace-all image warning
        .alert("All Images Will Be Lost", isPresented: $showingReplaceWarning, presenting: pendingImportData) { data in
            Button("Cancel", role: .cancel) {}
            Button("Replace All", role: .destructive) {
                importData(data: data, replace: true)
            }
        } message: { _ in
            Text("CSV files do not include photos. Replacing all data with a CSV import will permanently delete every vehicle photo stored in the app. Photos cannot be recovered after this action. Are you sure you want to continue?")
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
                },
                onEmailSelected: {
                    exportDataForEmail()
                }
            )
        }
        // Mail compose sheet
        .sheet(isPresented: $showingMailCompose) {
            if let url = mailAttachmentURL {
                MailComposeView(
                    attachmentURL: url,
                    subject: "Car Service App Backup",
                    body: "This email contains a backup file from the Car Service app.\n\nThe attached file includes your vehicles, service records, and upcoming maintenance data. You can import it back into the Car Service app at any time using the \"Import Data\" option in Settings.",
                    onFinish: {
                        showingMailCompose = false
                    }
                )
            }
        }
    }
    
    // MARK: - Email Export
    
    // Build a JSON backup file and open it in Mail with subject, body, and attachment pre-filled
    private func exportDataForEmail() {
        Task {
            do {
                let exportPayload = ExportData(
                    vehicles: vehicles.map { VehicleExport(from: $0, includePhotos: exportIncludePhotos) },
                    serviceRecords: services.map { ServiceRecordExport(from: $0) },
                    upcomingServices: upcoming.map { UpcomingServiceExport(from: $0) },
                    exportDate: Date(),
                    version: "1.0"
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(exportPayload)
                
                let fileName = "CarServiceBackup_\(Date().timeIntervalSince1970).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    mailAttachmentURL = tempURL
                    // Brief delay lets the format-picker sheet finish dismissing before
                    // we present the mail compose sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showingMailCompose = true
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Export failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    // MARK: - Share Sheet Presentation
    
    // Present UIActivityViewController from the key window's root view controller
    // Retries automatically if a sheet is currently being dismissed
    private func presentShareSheet(attempt: Int = 0) {
        guard !shareItems.isEmpty,
              let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow),
              var topController = window.rootViewController else {
            showingShareSheet = false
            return
        }
        
        // Walk up the chain to find the topmost non-dismissing presented view controller
        while let presented = topController.presentedViewController, !presented.isBeingDismissed {
            topController = presented
        }
        
        // If the top controller is being dismissed or already presenting something, retry shortly
        if topController.isBeingDismissed || topController.presentedViewController != nil {
            // Cap retries at ~2 seconds to avoid infinite loops
            if attempt < 20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    presentShareSheet(attempt: attempt + 1)
                }
            } else {
                showingShareSheet = false
            }
            return
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
    
    // Generate CSV data from vehicles, service records, and upcoming services
    private func generateCSV(includePhotos: Bool) throws -> Data {
        var csvLines: [String] = []
        let isoFormatter = ISO8601DateFormatter()
        
        // CSV Header — columns 0-12 match the original format; 13-20 are new
        csvLines.append(
            "Type,Vehicle Name,Make,Model,Year,VIN,Current Mileage," +
            "Service Type,Service Mileage,Service Date,Notes,Provider,Cost," +
            "License Plate,Oil Change Interval,Oil Weight,Oil Quantity,Oil Filter Part#," +
            "Target Mileage,Target Date,Completed"
        )
        
        // Vehicle rows — cols 0-12 blank for service-only columns, 13-17 carry vehicle specs
        for vehicle in vehicles {
            // 6 commas after currentMileage fill cols 7-12 (ServiceType through Cost) with blanks
            csvLines.append(
                "Vehicle," +
                "\(csvEscape(vehicle.displayName))," +
                "\(csvEscape(vehicle.make))," +
                "\(csvEscape(vehicle.model))," +
                "\(vehicle.year)," +
                "\(csvEscape(vehicle.vin ?? ""))," +
                "\(vehicle.currentMileage)" +
                ",,,,,,," + // 6 commas: cols 7-12 blank, then separator before col 13
                "\(csvEscape(vehicle.licensePlate ?? ""))," +
                "\(vehicle.oilChangeInterval)," +
                "\(csvEscape(vehicle.oilWeight))," +
                "\(csvEscape(vehicle.oilQuantity))," +
                "\(csvEscape(vehicle.oilFilterPartNumber))," +
                ",,"  // cols 18-20: TargetMileage, TargetDate, Completed blank
            )
        }
        
        // Service record rows — cols 13-17 carry vehicle specs for round-trip fidelity
        for service in services {
            let vehicleName = service.vehicle?.displayName ?? "Unknown"
            let costString = service.cost?.description ?? ""
            let dateString = isoFormatter.string(from: service.date)
            csvLines.append(
                "Service," +
                "\(csvEscape(vehicleName))," +
                "\(csvEscape(service.vehicle?.make ?? ""))," +
                "\(csvEscape(service.vehicle?.model ?? ""))," +
                "\(service.vehicle?.year ?? 0)," +
                "\(csvEscape(service.vehicle?.vin ?? ""))," +
                "," + // col 6: current mileage blank on service rows
                "\(csvEscape(service.serviceType.displayName))," +
                "\(service.mileage)," +
                "\(dateString)," +
                "\(csvEscape(service.notes))," +
                "\(csvEscape(service.provider ?? ""))," +
                "\(costString)," +
                "\(csvEscape(service.vehicle?.licensePlate ?? ""))," +
                "\(service.vehicle?.oilChangeInterval ?? 0)," +
                "\(csvEscape(service.vehicle?.oilWeight ?? ""))," +
                "\(csvEscape(service.vehicle?.oilQuantity ?? ""))," +
                "\(csvEscape(service.vehicle?.oilFilterPartNumber ?? ""))," +
                ",,"  // cols 18-20: upcoming cols blank
            )
        }
        
        // Upcoming service rows — cols 7-12 carry service-type info; 18-20 carry upcoming fields
        for upcomingService in upcoming {
            let vehicleName = upcomingService.vehicle?.displayName ?? "Unknown"
            let targetDateString = upcomingService.targetDate.map { isoFormatter.string(from: $0) } ?? ""
            csvLines.append(
                "Upcoming," +
                "\(csvEscape(vehicleName))," +
                "\(csvEscape(upcomingService.vehicle?.make ?? ""))," +
                "\(csvEscape(upcomingService.vehicle?.model ?? ""))," +
                "\(upcomingService.vehicle?.year ?? 0)," +
                "\(csvEscape(upcomingService.vehicle?.vin ?? ""))," +
                "," + // col 6: current mileage blank
                "\(csvEscape(upcomingService.serviceType.displayName))," +
                ",,," + // cols 8-10: service mileage/date/notes blank
                "," + // col 11: provider blank
                "," + // col 12: cost blank
                "\(csvEscape(upcomingService.vehicle?.licensePlate ?? ""))," +
                "\(upcomingService.vehicle?.oilChangeInterval ?? 0)," +
                "\(csvEscape(upcomingService.vehicle?.oilWeight ?? ""))," +
                "\(csvEscape(upcomingService.vehicle?.oilQuantity ?? ""))," +
                "\(csvEscape(upcomingService.vehicle?.oilFilterPartNumber ?? ""))," +
                "\(upcomingService.targetMileage)," +
                "\(targetDateString)," +
                "\(upcomingService.isCompleted ? "Yes" : "No")"
            )
        }
        
        let csvString = csvLines.joined(separator: "\n")
        guard let data = csvString.data(using: .utf8) else {
            throw NSError(domain: "CSVGeneration", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert CSV string to data"])
        }
        
        return data
    }
    
    // Wrap a string in quotes and escape internal quotes for CSV safety
    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
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
                    pendingImportData = importedData
                    pendingImportIsCSV = true
                    showingImportConfirmation = true
                } else {
                    // Parse JSON
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    let importedData = try decoder.decode(ExportData.self, from: data)
                    
                    pendingImportData = importedData
                    pendingImportIsCSV = false
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
        
        // Normalize line endings (Windows CRLF → LF)
        let normalizedCSV = csvString.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        var lines = normalizedCSV.components(separatedBy: "\n")
        guard !lines.isEmpty else {
            throw NSError(domain: "CSVImport", code: 0, userInfo: [NSLocalizedDescriptionKey: "CSV file is empty"])
        }
        
        // Remove header row
        _ = lines.removeFirst()
        
        var vehicles: [VehicleExport] = []
        var serviceRecords: [ServiceRecordExport] = []
        var upcomingServices: [UpcomingServiceExport] = []
        // Map display name ("2020 Toyota Camry") → VehicleExport for linking service rows
        var vehicleMapByName: [String: VehicleExport] = [:]
        
        // ISO 8601 formatter — allow fractional seconds and internet date/time format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateFormatterNoFraction = ISO8601DateFormatter()
        dateFormatterNoFraction.formatOptions = [.withInternetDateTime]
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            // Parse CSV line handling quoted fields
            let fields = parseCSVLine(line)
            guard fields.count >= 2 else { continue }
            
            let type = fields[0].trimmingCharacters(in: .whitespaces)
            
            if type == "Vehicle" && fields.count >= 7 {
                let vin = fields.count > 5 && !fields[5].isEmpty ? fields[5] : nil
                // Cols 13-17: License Plate, Oil Change Interval, Oil Weight, Oil Quantity, Oil Filter Part#
                let licensePlate = fields.count > 13 && !fields[13].isEmpty ? fields[13] : nil
                let oilInterval = fields.count > 14 ? Int(fields[14].replacingOccurrences(of: ",", with: "")) : nil
                let oilWeight = fields.count > 15 && !fields[15].isEmpty ? fields[15] : nil
                let oilQuantity = fields.count > 16 && !fields[16].isEmpty ? fields[16] : nil
                let oilFilter = fields.count > 17 && !fields[17].isEmpty ? fields[17] : nil
                let vehicleExport = VehicleExport(
                    id: UUID(),
                    make: fields.count > 2 ? fields[2] : "",
                    model: fields.count > 3 ? fields[3] : "",
                    year: Int(fields.count > 4 ? fields[4] : "0") ?? 0,
                    vin: vin,
                    currentMileage: Int((fields.count > 6 ? fields[6] : "0").replacingOccurrences(of: ",", with: "")) ?? 0,
                    oilChangeInterval: oilInterval,
                    oilWeight: oilWeight,
                    oilQuantity: oilQuantity,
                    oilFilterPartNumber: oilFilter,
                    photos: [],
                    createdAt: nil,
                    licensePlate: licensePlate
                )
                vehicles.append(vehicleExport)
                // Key by the vehicle's display name (matches fields[1] on service rows)
                let displayName = "\(vehicleExport.year) \(vehicleExport.make) \(vehicleExport.model)"
                vehicleMapByName[displayName] = vehicleExport
                // Also key directly by fields[1] in case the display name format differs
                vehicleMapByName[fields[1]] = vehicleExport
                
            } else if type == "Service" && fields.count >= 10 {
                let vehicleName = fields[1].trimmingCharacters(in: .whitespaces)
                
                // Look up existing vehicle, or create one from the vehicle columns in this row
                var vehicleExport = vehicleMapByName[vehicleName]
                if vehicleExport == nil && fields.count >= 5 {
                    let make = fields.count > 2 ? fields[2].trimmingCharacters(in: .whitespaces) : ""
                    let model = fields.count > 3 ? fields[3].trimmingCharacters(in: .whitespaces) : ""
                    let year = Int(fields.count > 4 ? fields[4].trimmingCharacters(in: .whitespaces) : "") ?? 0
                    let vin = fields.count > 5 && !fields[5].trimmingCharacters(in: .whitespaces).isEmpty
                        ? fields[5].trimmingCharacters(in: .whitespaces) : nil
                    // Use service mileage as a best guess for vehicle current mileage; strip commas
                    let mileage = Int((fields.count > 8 ? fields[8].trimmingCharacters(in: .whitespaces) : "").replacingOccurrences(of: ",", with: "")) ?? 0
                    
                    // Read oil specs from cols 13-17 if present on service rows too
                    let oilIntervalFS = fields.count > 14 ? Int(fields[14].replacingOccurrences(of: ",", with: "")) : nil
                    let oilWeightFS = fields.count > 15 && !fields[15].isEmpty ? fields[15] : nil
                    let oilQuantityFS = fields.count > 16 && !fields[16].isEmpty ? fields[16] : nil
                    let oilFilterFS = fields.count > 17 && !fields[17].isEmpty ? fields[17] : nil
                    let licensePlateFS = fields.count > 13 && !fields[13].isEmpty ? fields[13] : nil
                    
                    if !make.isEmpty || !model.isEmpty {
                        let newVehicleExport = VehicleExport(
                            id: UUID(),
                            make: make,
                            model: model,
                            year: year,
                            vin: vin,
                            currentMileage: mileage,
                            oilChangeInterval: oilIntervalFS,
                            oilWeight: oilWeightFS,
                            oilQuantity: oilQuantityFS,
                            oilFilterPartNumber: oilFilterFS,
                            photos: [],
                            createdAt: nil,
                            licensePlate: licensePlateFS
                        )
                        vehicles.append(newVehicleExport)
                        // Register under both the provided vehicle name and the computed display name
                        vehicleMapByName[vehicleName] = newVehicleExport
                        let computedName = "\(year) \(make) \(model)"
                        vehicleMapByName[computedName] = newVehicleExport
                        vehicleExport = newVehicleExport
                    }
                }
                
                // Parse cost as Decimal
                let cost: Decimal?
                // Strip $ prefix and comma thousands-separators before parsing (e.g. "$1,250.00" → "1250.00")
                let costRaw = fields.count > 12 ? fields[12].trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "") : ""
                if !costRaw.isEmpty, let costDouble = Double(costRaw) {
                    cost = Decimal(costDouble)
                } else {
                    cost = nil
                }
                
                let provider = fields.count > 11 && !fields[11].isEmpty ? fields[11] : nil
                
                // Try parsing date with and without fractional seconds
                let dateStr = fields.count > 9 ? fields[9] : ""
                let parsedDate = dateFormatter.date(from: dateStr)
                    ?? dateFormatterNoFraction.date(from: dateStr)
                    ?? Date()
                
                // Service mileage is at fields[8] in app-exported CSVs (fields[6] is blank).
                // Some user-created CSVs place mileage at fields[6] (Current Mileage column).
                // Strip comma thousands-separators (e.g. "45,000") before parsing.
                // Try fields[8] first; fall back to fields[6] if fields[8] is absent or zero.
                let serviceMileageStr8 = fields.count > 8 ? fields[8].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "") : ""
                let serviceMileageStr6 = fields.count > 6 ? fields[6].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "") : ""
                let parsedMileage8 = Int(serviceMileageStr8) ?? 0
                let parsedMileage6 = Int(serviceMileageStr6) ?? 0
                let serviceMileage = parsedMileage8 > 0 ? parsedMileage8 : parsedMileage6
                
                let serviceRecordExport = ServiceRecordExport(
                    id: UUID(),
                    vehicleId: vehicleExport?.id ?? UUID(),
                    serviceType: fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : "Other",
                    mileage: serviceMileage,
                    date: parsedDate,
                    notes: fields.count > 10 ? fields[10] : "",
                    provider: provider,
                    cost: cost,
                    createdAt: nil
                )
                serviceRecords.append(serviceRecordExport)
                
            } else if type == "Upcoming" && fields.count >= 8 {
                let vehicleName = fields[1].trimmingCharacters(in: .whitespaces)
                let vehicleExport = vehicleMapByName[vehicleName]
                
                // Col 7: service type, col 18: target mileage, col 19: target date, col 20: completed
                let targetMileageStr = fields.count > 18 ? fields[18].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "") : ""
                let targetMileage = Int(targetMileageStr) ?? 0
                let targetDateStr = fields.count > 19 ? fields[19].trimmingCharacters(in: .whitespaces) : ""
                let targetDate = dateFormatter.date(from: targetDateStr) ?? dateFormatterNoFraction.date(from: targetDateStr)
                let isCompleted = fields.count > 20 ? fields[20].trimmingCharacters(in: .whitespaces).lowercased() == "yes" : false
                
                let upcomingExport = UpcomingServiceExport(
                    id: UUID(),
                    vehicleId: vehicleExport?.id ?? UUID(),
                    serviceType: fields[7].trimmingCharacters(in: .whitespaces),
                    targetMileage: targetMileage,
                    targetDate: targetDate,
                    notes: "",
                    isCompleted: isCompleted,
                    createdAt: nil
                )
                upcomingServices.append(upcomingExport)
            }
        }
        
        return ExportData(
            vehicles: vehicles,
            serviceRecords: serviceRecords,
            upcomingServices: upcomingServices,
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
        
        // Build a lookup of existing vehicles by display name for merge deduplication.
        // On replace-all we skip this entirely — clearAllData() already ran but @Query
        // still holds stale references to the deleted objects, so we must not reuse them.
        var existingVehicleLookup: [String: Vehicle] = [:]
        if !replace {
            for vehicle in vehicles {
                existingVehicleLookup[vehicle.displayName] = vehicle
            }
        }
        
        // Map exported UUIDs to the Vehicle instance that will own imported records
        var vehicleMap: [UUID: Vehicle] = [:]
        
        for vehicleExport in data.vehicles {
            let displayName = "\(vehicleExport.year) \(vehicleExport.make) \(vehicleExport.model)"
            
            let vehicle: Vehicle
            if let existing = existingVehicleLookup[displayName] {
                // Vehicle already exists — reuse it, update mileage if the import has a higher value
                if vehicleExport.currentMileage > existing.currentMileage {
                    existing.currentMileage = vehicleExport.currentMileage
                }
                vehicle = existing
            } else {
                // New vehicle — insert it
                let newVehicle = Vehicle(
                    make: vehicleExport.make,
                    model: vehicleExport.model,
                    year: vehicleExport.year,
                    vin: vehicleExport.vin,
                    licensePlate: vehicleExport.licensePlate,
                    currentMileage: vehicleExport.currentMileage,
                    oilChangeInterval: vehicleExport.oilChangeInterval ?? 5000,
                    oilWeight: vehicleExport.oilWeight ?? "",
                    oilQuantity: vehicleExport.oilQuantity ?? "",
                    oilFilterPartNumber: vehicleExport.oilFilterPartNumber ?? "",
                    createdAt: vehicleExport.createdAt
                )
                modelContext.insert(newVehicle)
                
                // Import photos for new vehicles only
                for photoExport in vehicleExport.photos {
                    if let imageData = Data(base64Encoded: photoExport.imageData) {
                        let photo = VehiclePhoto(
                            imageData: imageData,
                            caption: photoExport.caption,
                            isThumbnail: photoExport.isThumbnail,
                            vehicle: newVehicle,
                            createdAt: photoExport.createdAt
                        )
                        modelContext.insert(photo)
                    }
                }
                
                vehicle = newVehicle
            }
            
            vehicleMap[vehicleExport.id] = vehicle
        }
        
        // Import service records, skipping exact duplicates (same vehicle, date, mileage, type)
        for recordExport in data.serviceRecords {
            guard let vehicle = vehicleMap[recordExport.vehicleId] else { continue }
            
            let serviceType = ServiceType(rawValue: recordExport.serviceType) ?? .other
            let isDuplicate = vehicle.services?.contains(where: {
                $0.date == recordExport.date &&
                $0.mileage == recordExport.mileage &&
                $0.serviceType == serviceType
            }) ?? false
            
            guard !isDuplicate else { continue }
            
            let record = ServiceRecord(
                serviceType: serviceType,
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
        
        // Import upcoming services, skipping exact duplicates (same vehicle, type, target mileage)
        for upcomingExport in data.upcomingServices {
            guard let vehicle = vehicleMap[upcomingExport.vehicleId] else { continue }
            
            let serviceType = ServiceType(rawValue: upcomingExport.serviceType) ?? .other
            let isDuplicate = vehicle.upcomingServices?.contains(where: {
                $0.serviceType == serviceType &&
                $0.targetMileage == upcomingExport.targetMileage &&
                !$0.isCompleted
            }) ?? false
            
            guard !isDuplicate else { continue }
            
            let upcomingService = UpcomingService(
                serviceType: serviceType,
                targetMileage: upcomingExport.targetMileage,
                targetDate: upcomingExport.targetDate,
                notes: upcomingExport.notes,
                vehicle: vehicle,
                createdAt: upcomingExport.createdAt
            )
            upcomingService.isCompleted = upcomingExport.isCompleted
            modelContext.insert(upcomingService)
        }
        
        // Count how many service records were actually linked (had a matching vehicle)
        let linkedServiceCount = data.serviceRecords.filter { vehicleMap[$0.vehicleId] != nil }.count
        alertMessage = "Import completed! Vehicles: \(data.vehicles.count), Service records parsed: \(data.serviceRecords.count), linked to vehicles: \(linkedServiceCount)."
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
    let onEmailSelected: () -> Void
    
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
                        }
                    }
                    
                    // Email option — opens Mail with subject, body, and attachment pre-filled
                    if MFMailComposeViewController.canSendMail() {
                        Button {
                            onEmailSelected()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.orange)
                                Text("Email Backup")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                } header: {
                    Text("Export Format")
                } footer: {
                    Text(includePhotos
                        ? "JSON preserves all data including photos. CSV is a spreadsheet-friendly format without photos. Email sends a JSON backup directly."
                        : "JSON preserves all data structure. CSV is a spreadsheet-friendly format for easy viewing in Excel or Numbers. Email sends a JSON backup directly.")
                }
            }
            .navigationTitle("Choose Format")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Mail Compose View
// UIViewControllerRepresentable wrapper around MFMailComposeViewController
// so we can pre-fill subject, body, and attach the backup file
struct MailComposeView: UIViewControllerRepresentable {
    let attachmentURL: URL
    let subject: String
    let body: String
    let onFinish: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        
        // Attach the backup file
        if let data = try? Data(contentsOf: attachmentURL) {
            let mimeType = attachmentURL.pathExtension == "csv" ? "text/csv" : "application/json"
            vc.addAttachmentData(data, mimeType: mimeType, fileName: attachmentURL.lastPathComponent)
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        
        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true)
            onFinish()
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
    let licensePlate: String?
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
        self.licensePlate = vehicle.licensePlate
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
    init(id: UUID, make: String, model: String, year: Int, vin: String?, currentMileage: Int, oilChangeInterval: Int?, oilWeight: String?, oilQuantity: String?, oilFilterPartNumber: String?, photos: [VehiclePhotoExport], createdAt: Date?, licensePlate: String? = nil) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.licensePlate = licensePlate
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
    
    // Initializer for CSV import
    init(id: UUID, vehicleId: UUID, serviceType: String, targetMileage: Int, targetDate: Date?, notes: String, isCompleted: Bool, createdAt: Date?) {
        self.id = id
        self.vehicleId = vehicleId
        self.serviceType = serviceType
        self.targetMileage = targetMileage
        self.targetDate = targetDate
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt ?? Date()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Vehicle.self, ServiceRecord.self, VehiclePhoto.self, UpcomingService.self], inMemory: true)
}
