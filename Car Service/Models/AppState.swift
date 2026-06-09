//
//  AppState.swift
//  Car Service
//
//  Shared observable state for app-wide navigation (e.g. active tab selection)
//

import SwiftUI
import Combine

/// Holds app-level UI state that needs to be shared across unrelated views.
final class AppState: ObservableObject {
    @Published var selectedTab: Int = 0
}
