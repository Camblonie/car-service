//
//  ServiceType.swift
//  Car Service
//
//  Enum defining all predefined service types with display info
//

import Foundation
import SwiftUI

enum ServiceType: String, CaseIterable, Codable {
    case oilChange = "Oil Change"
    case tireRotation = "Tire Rotation"
    case tireReplacement = "Tire Replacement"
    case brakeService = "Brake Service"
    case transmissionService = "Transmission Service"
    case airFilter = "Air Filter"
    case cabinFilter = "Cabin Filter"
    case coolantFlush = "Coolant Flush"
    case sparkPlugs = "Spark Plugs"
    case other = "Other"
    
    // Display name
    var displayName: String {
        rawValue
    }
    
    // System image name for each service type
    var iconName: String {
        switch self {
        case .oilChange:
            return "drop.fill"
        case .tireRotation:
            return "arrow.2.circlepath"
        case .tireReplacement:
            return "circle.hexagongrid.fill"
        case .brakeService:
            return "exclamationmark.octagon.fill"
        case .transmissionService:
            return "gearshape.fill"
        case .airFilter:
            return "wind"
        case .cabinFilter:
            return "fan.fill"
        case .coolantFlush:
            return "thermometer"
        case .sparkPlugs:
            return "bolt.fill"
        case .other:
            return "wrench.fill"
        }
    }
    
    // Color for each service type
    var color: Color {
        switch self {
        case .oilChange:
            return .orange
        case .tireRotation, .tireReplacement:
            return .blue
        case .brakeService:
            return .red
        case .transmissionService:
            return .purple
        case .airFilter, .cabinFilter:
            return .green
        case .coolantFlush:
            return .cyan
        case .sparkPlugs:
            return .yellow
        case .other:
            return .gray
        }
    }
}
