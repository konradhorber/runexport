//
//  Run.swift
//  runexport
//
//  Created by Konrad on 08.03.26.
//

import Foundation

struct Run: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let distance: Double // meters
    let duration: TimeInterval // seconds
    let calories: Double?
    let averageHeartRate: Double?
    let route: [LocationPoint]?
    
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

struct LocationPoint: Codable {
    let latitude: Double
    let longitude: Double
    let altitude: Double?
    let timestamp: Date
}

// MARK: - API Request Format
struct RunExportRequest: Codable {
    let runs: [Run]
    let deviceId: String
    let exportDate: Date
}
