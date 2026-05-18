//
//  ServiceRecord.swift
//  Car Service
//
//  Data model representing a completed service record
//

import Foundation
import SwiftData

@Model
final class ServiceRecord {
    @Attribute(.unique) var id: UUID
    var serviceTypeRaw: String
    var mileage: Int
    var date: Date
    var notes: String
    var provider: String?
    var cost: Decimal?
    var createdAt: Date
    
    // Relationship to vehicle
    var vehicle: Vehicle?
    
    // Computed property to get ServiceType enum
    var serviceType: ServiceType {
        ServiceType(rawValue: serviceTypeRaw) ?? .other
    }
    
    init(
        serviceType: ServiceType,
        mileage: Int,
        date: Date = Date(),
        notes: String = "",
        provider: String? = nil,
        cost: Decimal? = nil,
        vehicle: Vehicle? = nil,
        createdAt: Date? = nil
    ) {
        self.id = UUID()
        self.serviceTypeRaw = serviceType.rawValue
        self.mileage = mileage
        self.date = date
        self.notes = notes
        self.provider = provider
        self.cost = cost
        self.vehicle = vehicle
        self.createdAt = createdAt ?? Date()
    }
}
