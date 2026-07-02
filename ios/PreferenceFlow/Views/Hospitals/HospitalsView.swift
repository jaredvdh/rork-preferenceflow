//
//  HospitalsView.swift
//  PreferenceFlow
//

import SwiftUI

/// Hospitals tab — list of facilities with provider counts.
struct HospitalsView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings

    @State private var editing: Hospital?
    @State private var creatingNew = false
    var embedInStack: Bool = true

    var body: some View {
        if embedInStack {
            NavigationStack { content }
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            if store.hospitals.isEmpty {
                EmptyStateView(
                    icon: "building.2",
                    title: "No hospitals yet",
                    message: "Add the facilities where you work to organise providers by site.",
                    actionTitle: "Add Hospital",
                    action: { creatingNew = true }
                )
            } else {
                listContent
            }
        }
        .navigationTitle("Hospitals")
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: KnowledgeCategory.self) { KnowledgeCategoryView(category: $0) }
        .navigationDestination(for: KnowledgeArticle.self) { KnowledgeArticleView(article: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creatingNew = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $creatingNew) {
            HospitalEditView(hospital: Hospital())
        }
        .sheet(item: $editing) { hospital in
            HospitalEditView(hospital: hospital)
        }
        .onAppear(perform: consumePendingAdd)
        .onChange(of: settings.pendingOpenAddHospital) { _, _ in consumePendingAdd() }
    }

    /// Opens the add-hospital flow when the guided tour requested it.
    private func consumePendingAdd() {
        guard settings.pendingOpenAddHospital else { return }
        settings.pendingOpenAddHospital = false
        creatingNew = true
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.hospitals) { hospital in
                    NavigationLink {
                        HospitalDetailView(hospitalID: hospital.id)
                    } label: {
                        HospitalRow(hospital: hospital, count: store.doctorCount(forHospital: hospital.id))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editing = hospital } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { store.deleteHospital(hospital) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

/// A single hospital card row.
struct HospitalRow: View {
    let hospital: Hospital
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerMedium)
                    .fill(Theme.accent.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: "building.2.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(hospital.name.isBlank ? "Untitled Hospital" : hospital.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if hospital.isDemo { DemoBadge() }
                }
                if !hospital.locationLine.isEmpty {
                    Text(hospital.locationLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !hospital.department.isBlank {
                    Text(hospital.department)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(count == 1 ? "provider" : "providers")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .card()
    }
}
