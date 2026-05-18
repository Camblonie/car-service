//
//  VehiclePhoto.swift
//  Car Service
//
//  Data model storing vehicle photos with thumbnail support
//

import Foundation
import SwiftData
import UIKit

@Model
final class VehiclePhoto {
    @Attribute(.unique) var id: UUID
    var imageData: Data
    var caption: String?
    var isThumbnail: Bool
    var createdAt: Date
    
    // Relationship to vehicle
    var vehicle: Vehicle?
    
    // Computed property to get UIImage
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    init(
        imageData: Data,
        caption: String? = nil,
        isThumbnail: Bool = false,
        vehicle: Vehicle? = nil,
        createdAt: Date? = nil
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.caption = caption
        self.isThumbnail = isThumbnail
        self.vehicle = vehicle
        self.createdAt = createdAt ?? Date()
    }
}
