//
//  ContentView.swift
//  runexport
//
//  Created by Konrad on 08.03.26.
//

import SwiftUI

struct ContentView: View {
    @State private var healthKitManager = HealthKitManager()
    @State private var isExporting = false
    @State private var exportMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if healthKitManager.runs.isEmpty && !healthKitManager.isLoading {
                    emptyStateView
                } else {
                    runsList
                }
            }
            .navigationTitle("Run Export")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await exportRuns()
                        }
                    } label: {
                        Label("Export Runs", systemImage: "arrow.up.doc")
                    }
                    .disabled(healthKitManager.runs.isEmpty || isExporting)
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        Task {
                            await loadRuns()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(healthKitManager.isLoading)
                }
            }
            .task {
                await requestHealthKitAccess()
            }
            .alert("Export Status", isPresented: .constant(exportMessage != nil)) {
                Button("OK") {
                    exportMessage = nil
                }
            } message: {
                if let message = exportMessage {
                    Text(message)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                if let error = healthKitManager.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Runs Found", systemImage: "figure.run")
        } description: {
            Text("Your running workouts will appear here once you authorize HealthKit access.")
        } actions: {
            Button("Load Runs") {
                Task {
                    await loadRuns()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var runsList: some View {
        List {
            Section {
                ForEach(healthKitManager.runs) { run in
                    RunRowView(run: run)
                }
            } header: {
                Text("\(healthKitManager.runs.count) runs")
            }
        }
        .overlay {
            if healthKitManager.isLoading {
                ProgressView("Loading runs...")
            }
        }
        .overlay {
            if isExporting {
                ProgressView("Exporting...")
            }
        }
    }
    
    private func requestHealthKitAccess() async {
        do {
            try await healthKitManager.requestAuthorization()
            await loadRuns()
        } catch {
            healthKitManager.error = error
            showError = true
        }
    }
    
    private func loadRuns() async {
        do {
            try await healthKitManager.fetchRuns()
        } catch {
            healthKitManager.error = error
            showError = true
        }
    }
    
    private func exportRuns() async {
        isExporting = true
        defer { isExporting = false }
        
        do {
            let apiClient = APIClient()
            let response = try await apiClient.exportRuns(healthKitManager.runs)
            exportMessage = "Successfully exported \(response.runsProcessed) runs!"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

struct RunRowView: View {
    let run: Run
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(run.startDate, style: .date)
                .font(.headline)
            
            HStack(spacing: 16) {
                Label {
                    Text(String(format: "%.2f km", run.distanceInKilometers))
                } icon: {
                    Image(systemName: "figure.run")
                }
                
                Label {
                    Text(formatDuration(run.duration))
                } icon: {
                    Image(systemName: "timer")
                }
                
                Label {
                    Text(formatPace(run.pacePerKilometer))
                } icon: {
                    Image(systemName: "speedometer")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatPace(_ pace: TimeInterval) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
