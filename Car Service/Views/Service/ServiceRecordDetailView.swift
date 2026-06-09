//
//  ServiceRecordDetailView.swift
//  Car Service
//
//  Detailed view of a single service record
//

import SwiftUI
import SwiftData

struct ServiceRecordDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let record: ServiceRecord

    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            // Service type header
            Section {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(record.serviceType.color.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: record.serviceType.iconName)
                            .font(.system(size: 26))
                            .foregroundColor(record.serviceType.color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.serviceType.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let vehicleName = record.vehicle?.displayName {
                            Text(vehicleName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Core details
            Section("Details") {
                LabeledRow(label: "Date") {
                    Text(record.date, format: .dateTime.month().day().year())
                }

                LabeledRow(label: "Mileage") {
                    Text("\(record.mileage) mi")
                }

                if let cost = record.cost {
                    LabeledRow(label: "Cost") {
                        Text("$\(cost, format: .number.precision(.fractionLength(2)))")
                    }
                }

                if let provider = record.provider, !provider.isEmpty {
                    LabeledRow(label: "Provider") {
                        Text(provider)
                    }
                }
            }

            // Notes
            if !record.notes.isEmpty {
                Section("Notes") {
                    Text(record.notes)
                        .font(.body)
                }
            }

            // Delete action
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Record", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Service Record")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Record?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("This will permanently delete this service record. This action cannot be undone.")
        }
    }

    private func deleteRecord() {
        modelContext.delete(record)
        dismiss()
    }
}

// MARK: - Labeled Row Helper
// Reusable row with a left label and right-aligned content
struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            content()
                .multilineTextAlignment(.trailing)
        }
    }
}
