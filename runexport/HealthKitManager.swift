//
//  HealthKitManager.swift
//  runexport
//
//  Created by Konrad on 08.03.26.
//

import CoreLocation
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
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKSeriesType.workoutRoute()
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
                    let splits = try? await self.fetchKilometerSplits(for: workout)

                    return Run(
                        id: workout.uuid,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        distance: distanceMeters,
                        duration: workout.duration,
                        isIndoor: (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false,
                        calories: workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                        averageHeartRate: avgHR,
                        maxHeartRate: maxHR,
                        averagePacePerKilometer: distanceMeters > 0 ? workout.duration / (distanceMeters / 1000.0) : nil,
                        totalElevationAscent: ascent,
                        totalElevationDescent: descent,
                        workoutEvents: (workout.workoutEvents ?? []).compactMap { self.workoutEvent(from: $0) },
                        splits: splits?.isEmpty == false ? splits : nil
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

    private func workoutEvent(from event: HKWorkoutEvent) -> WorkoutEvent? {
        let type: WorkoutEventType
        switch event.type {
        case .pause:          type = .pause
        case .resume:         type = .resume
        case .lap:            type = .lap
        case .marker:         type = .marker
        case .motionPaused:   type = .motionPaused
        case .motionResumed:  type = .motionResumed
        case .segment:        type = .segment
        case .pauseDetected:  type = .pauseDetected
        case .resumeDetected: type = .resumeDetected
        @unknown default:     return nil
        }
        return WorkoutEvent(type: type, startDate: event.dateInterval.start, endDate: event.dateInterval.end)
    }

    private func fetchKilometerSplits(for workout: HKWorkout) async throws -> [KilometerSplit] {
        let locations = try await fetchWorkoutRouteLocations(for: workout)
        guard locations.count >= 2 else { return [] }

        var splits: [KilometerSplit] = []
        var cumulativeDistance: Double = 0
        var kmNumber = 1
        var segmentStartTime = locations[0].timestamp
        var elevAscent: Double = 0
        var elevDescent: Double = 0

        for i in 1..<locations.count {
            let prev = locations[i - 1]
            let curr = locations[i]

            cumulativeDistance += curr.distance(from: prev)
            let altDelta = curr.altitude - prev.altitude
            if altDelta > 0 { elevAscent += altDelta } else { elevDescent += abs(altDelta) }

            while cumulativeDistance >= Double(kmNumber) * 1000.0 {
                let end = curr.timestamp
                let duration = end.timeIntervalSince(segmentStartTime)
                let avgHR = try? await fetchAverageHeartRate(from: segmentStartTime, to: end)

                splits.append(KilometerSplit(
                    kilometer: kmNumber,
                    pace: duration,
                    averageHeartRate: avgHR,
                    elevationAscent: elevAscent > 0 ? elevAscent : nil,
                    elevationDescent: elevDescent > 0 ? elevDescent : nil
                ))
                segmentStartTime = end
                elevAscent = 0
                elevDescent = 0
                kmNumber += 1
            }
        }

        // Partial final km (at least 100m to be meaningful)
        let remainder = cumulativeDistance - Double(kmNumber - 1) * 1000.0
        if remainder >= 100 {
            let end = locations.last!.timestamp
            let duration = end.timeIntervalSince(segmentStartTime)
            let avgHR = try? await fetchAverageHeartRate(from: segmentStartTime, to: end)
            splits.append(KilometerSplit(
                kilometer: kmNumber,
                pace: duration / (remainder / 1000.0),
                averageHeartRate: avgHR,
                elevationAscent: elevAscent > 0 ? elevAscent : nil,
                elevationDescent: elevDescent > 0 ? elevDescent : nil
            ))
        }

        return splits
    }

    private func fetchWorkoutRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let routeType = HKSeriesType.workoutRoute()
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: routeType, predicate: workoutPredicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
            }
            self.healthStore.execute(query)
        }

        guard let route = routes.first else { return [] }

        var allLocations: [CLLocation] = []
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let locations { allLocations.append(contentsOf: locations) }
                if done { continuation.resume() }
            }
            self.healthStore.execute(query)
        }

        return allLocations.sorted { $0.timestamp < $1.timestamp }
    }

    private func fetchAverageHeartRate(from start: Date, to end: Date) async throws -> Double? {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate, .strictEndDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let unit = HKUnit.count().unitDivided(by: .minute())
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            self.healthStore.execute(query)
        }
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
