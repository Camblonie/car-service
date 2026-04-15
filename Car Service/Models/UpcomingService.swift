//
//  UpcomingService.swift
//  Car Service
//
//  Data model for planned future maintenance
//

import Foundation
import SwiftData

@Model
final class UpcomingService {
    @Attribute(.unique) var id: UUID
    var serviceTypeRaw: String
    var targetMileage: Int
    var targetDate: Date?
    var notes: String
    var isCompleted: Bool
    var createdAt: Date
    
    // Relationship to vehicle
    var vehicle: Vehicle?
    
    // Computed property to get ServiceType enum
    var serviceType: ServiceType {
        ServiceType(rawValue: serviceTypeRaw) ?? .other
    }
    
    init(
        serviceType: ServiceType,
        targetMileage: Int,
        targetDate: Date? = nil,
        notes: String = "",
        vehicle: Vehicle? = nil
    ) {
        self.id = UUID()
        self.serviceTypeRaw = serviceType.rawValue
        self.targetMileage = targetMileage
        self.targetDate = targetDate
        self.notes = notes
        self.isCompleted = false
        self.vehicle = vehicle
        self.createdAt = Date()
    }
}
