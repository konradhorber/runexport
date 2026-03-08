//
//  HealthKitManager.swift
//  runexport
//
//  Created by Konrad on 08.03.26.
//

import Foundation
import HealthKit
import Observation

@Observable
@MainActor
class HealthKitManager {
    private let healthStore = HKHealthStore()

    var runs: [Run] = []
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    var isLoading = false
    var error: Error?
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let workoutType = HKObjectType.workoutType()

        let typesToRead: Set<HKObjectType> = [
            workoutType,
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
        
        runs = workouts.map { workout in
            Run(
                id: UUID(uuidString: workout.uuid.uuidString) ?? UUID(),
                startDate: workout.startDate,
                endDate: workout.endDate,
                distance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                duration: workout.duration,
                calories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                averageHeartRate: nil
            )
        }
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
