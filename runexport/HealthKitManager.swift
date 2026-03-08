//
//  HealthKitManager.swift
//  runexport
//
//  Created by Konrad on 08.03.26.
//

import Foundation
import HealthKit
import CoreLocation
import Observation

@Observable
@MainActor
class HealthKitManager {
    private let healthStore = HKHealthStore()

    var runs: [Run] = []
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    var isLoading = false
    var error: Error?
    
    // Request authorization to read workout and route data
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let workoutType = HKObjectType.workoutType()
        let routeType = HKSeriesType.workoutRoute()
        
        let typesToRead: Set<HKObjectType> = [
            workoutType,
            routeType,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        
        authorizationStatus = healthStore.authorizationStatus(for: workoutType)
    }
    
    // Fetch all running workouts
    func fetchRuns(from startDate: Date? = nil) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let workoutType = HKObjectType.workoutType()
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        
        var predicates = [runningPredicate]
        if let startDate = startDate {
            let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
            predicates.append(datePredicate)
        }
        
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let workouts = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(sampleType: workoutType, predicate: compound, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
        
        // Convert HKWorkouts to Run objects
        var convertedRuns: [Run] = []
        
        for workout in workouts {
            // Fetch route data for this workout
            let route = try? await fetchRoute(for: workout)
            
            let run = Run(
                id: UUID(uuidString: workout.uuid.uuidString) ?? UUID(),
                startDate: workout.startDate,
                endDate: workout.endDate,
                distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                duration: workout.duration,
                calories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                averageHeartRate: nil, // Could fetch this separately if needed
                route: route
            )
            
            convertedRuns.append(run)
        }
        
        runs = convertedRuns
    }
    
    // Fetch route data for a specific workout
    private func fetchRoute(for workout: HKWorkout) async throws -> [LocationPoint]? {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        
        let routes = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKWorkoutRoute], Error>) in
            let query = HKSampleQuery(sampleType: routeType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let routes = samples as? [HKWorkoutRoute] ?? []
                continuation.resume(returning: routes)
            }
            
            healthStore.execute(query)
        }
        
        guard let route = routes.first else { return nil }
        
        // Fetch location data from the route
        var locationPoints: [LocationPoint] = []
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let locations = locations {
                    let points = locations.map { location in
                        LocationPoint(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            altitude: location.altitude,
                            timestamp: location.timestamp
                        )
                    }
                    locationPoints.append(contentsOf: points)
                }
                
                if done {
                    continuation.resume()
                }
            }
            
            healthStore.execute(query)
        }
        
        return locationPoints.isEmpty ? nil : locationPoints
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        }
    }
}
