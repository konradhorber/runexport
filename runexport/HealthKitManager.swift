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
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }

        // Fetch heart rate for all workouts concurrently
        var convertedRuns = await withTaskGroup(of: Run.self) { group in
            for workout in workouts {
                group.addTask {
                    let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
                    let (avgHR, maxHR) = (try? await self.fetchHeartRateStats(for: workout)) ?? (nil, nil)
                    let ascent = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter())
                    let descent = (workout.metadata?[HKMetadataKeyElevationDescended] as? HKQuantity)?.doubleValue(for: .meter())

                    return Run(
                        id: UUID(uuidString: workout.uuid.uuidString) ?? UUID(),
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        distance: distanceMeters,
                        duration: workout.duration,
                        calories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                        averageHeartRate: avgHR,
                        maxHeartRate: maxHR,
                        averagePacePerKilometer: distanceMeters > 0 ? workout.duration / (distanceMeters / 1000.0) : nil,
                        totalElevationAscent: ascent,
                        totalElevationDescent: descent
                    )
                }
            }
            var result: [Run] = []
            for await run in group { result.append(run) }
            return result
        }

        // Restore original sort order (TaskGroup doesn't preserve it)
        convertedRuns.sort { $0.startDate > $1.startDate }
        runs = convertedRuns
    }

    private func fetchHeartRateStats(for workout: HKWorkout) async throws -> (average: Double?, max: Double?) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, stats, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                let avg = stats?.averageQuantity()?.doubleValue(for: unit)
                let max = stats?.maximumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: (avg, max))
            }
            self.healthStore.execute(query)
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
