//
//  Vehicle.swift
//  Car Service
//
//  Data model representing a vehicle with its maintenance specifications
//

import Foundation
import SwiftData

@Model
final class Vehicle {
    @Attribute(.unique) var id: UUID
    var make: String
    var model: String
    var year: Int
    var vin: String?
    var licensePlate: String?
    var currentMileage: Int
    var oilChangeInterval: Int
    var oilWeight: String
    var oilQuantity: String
    var oilFilterPartNumber: String
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var services: [ServiceRecord]?
    @Relationship(deleteRule: .cascade) var photos: [VehiclePhoto]?
    @Relationship(deleteRule: .cascade) var upcomingServices: [UpcomingService]?
    
    init(
        make: String,
        model: String,
        year: Int,
        vin: String? = nil,
        licensePlate: String? = nil,
        currentMileage: Int = 0,
        oilChangeInterval: Int = 5000,
        oilWeight: String = "",
        oilQuantity: String = "",
        oilFilterPartNumber: String = "",
        createdAt: Date? = nil
    ) {
        self.id = UUID()
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
        self.createdAt = createdAt ?? Date()
        self.services = []
        self.photos = []
        self.upcomingServices = []
    }
    
    // Computed property for display name
    var displayName: String {
        "\(year) \(make) \(model)"
    }
    
    // Get the thumbnail photo if available
    var thumbnailPhoto: VehiclePhoto? {
        photos?.first { $0.isThumbnail }
    }
    
    // Calculate next oil change mileage based on last service
    var nextOilChangeMileage: Int? {
        guard let lastOilChange = services?
            .filter({ $0.serviceType == .oilChange })
            .sorted(by: { $0.mileage > $1.mileage })
            .first else {
            return nil
        }
        return lastOilChange.mileage + oilChangeInterval
    }
    
    // Miles until next oil change
    var milesUntilOilChange: Int? {
        guard let nextMileage = nextOilChangeMileage else { return nil }
        return nextMileage - currentMileage
    }
}
