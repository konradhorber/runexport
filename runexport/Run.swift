//
//  Run.swift
//  runexport
//
//  Created by Konrad on 08.03.26.
//

import Foundation

enum WorkoutEventType: String, Codable, CaseIterable {
    case pause, resume, lap, marker
    case motionPaused, motionResumed
    case segment
    case pauseDetected, resumeDetected
}

struct WorkoutEvent: Codable {
    let type: WorkoutEventType
    let startDate: Date
    let endDate: Date
}

struct KilometerSplit: Codable {
    let kilometer: Int
    let pace: Double              // seconds/km
    let averageHeartRate: Double? // bpm
    let elevationAscent: Double?  // meters
    let elevationDescent: Double? // meters
}

struct Run: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let distance: Double          // meters
    let duration: TimeInterval    // seconds
    let isIndoor: Bool
    let calories: Double?
    let averageHeartRate: Double? // bpm
    let maxHeartRate: Double?     // bpm
    let averagePacePerKilometer: Double? // seconds/km
    let totalElevationAscent: Double?    // meters
    let totalElevationDescent: Double?   // meters
    let workoutEvents: [WorkoutEvent]
    let splits: [KilometerSplit]?

    var distanceInKilometers: Double {
        distance / 1000.0
    }

    var distanceInMiles: Double {
        distance / 1609.34
    }

    var pacePerKilometer: TimeInterval {
        guard distanceInKilometers > 0 else { return 0 }
        return duration / distanceInKilometers
    }

    var pacePerMile: TimeInterval {
        guard distanceInMiles > 0 else { return 0 }
        return duration / distanceInMiles
    }
}

// MARK: - API Request Format
struct RunExportRequest: Codable {
    let runs: [Run]
    let deviceId: String
    let exportDate: Date
}
