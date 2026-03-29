//
//  TestFixtures.swift
//  runexportTests
//
// Realistic mock Run objects for use across test suites.
// Fixed UUIDs and timestamps make test output deterministic and easy to read.
//

import Foundation
@testable import runexport

enum RunFixtures {

    // A standard outdoor 5 km run with all optional data present.
    static let outdoor5km = Run(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        startDate: Date(timeIntervalSince1970: 1_740_000_000),
        endDate:   Date(timeIntervalSince1970: 1_740_001_560),
        distance: 5_000,
        duration: 1_560,           // 26:00 total → ~5:12/km
        isIndoor: false,
        calories: 350,
        averageHeartRate: 162,
        maxHeartRate: 181,
        averagePacePerKilometer: 312,
        totalElevationAscent: 48,
        totalElevationDescent: 45,
        splits: [
            KilometerSplit(kilometer: 1, pace: 305, averageHeartRate: 154, elevationAscent: 12,   elevationDescent: nil),
            KilometerSplit(kilometer: 2, pace: 310, averageHeartRate: 161, elevationAscent: nil,  elevationDescent: 8),
            KilometerSplit(kilometer: 3, pace: 318, averageHeartRate: 165, elevationAscent: 22,   elevationDescent: nil),
            KilometerSplit(kilometer: 4, pace: 308, averageHeartRate: 167, elevationAscent: nil,  elevationDescent: 15),
            KilometerSplit(kilometer: 5, pace: 319, averageHeartRate: 170, elevationAscent: 14,   elevationDescent: 22),
        ],
        workoutActivities: nil
    )

    // An indoor treadmill run.
    // isIndoor = true, no GPS route → splits and elevation are nil.
    static let indoorTreadmill = Run(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        startDate: Date(timeIntervalSince1970: 1_740_100_000),
        endDate:   Date(timeIntervalSince1970: 1_740_102_400),
        distance: 8_000,
        duration: 2_400,           // 40:00 → 5:00/km (treadmill-reported)
        isIndoor: true,
        calories: 520,
        averageHeartRate: 158,
        maxHeartRate: 178,
        averagePacePerKilometer: 300,
        totalElevationAscent: nil, // not recorded indoors
        totalElevationDescent: nil,
        splits: nil,               // no GPS route
        workoutActivities: nil
    )

    // An outdoor interval run without workoutActivities (e.g. older recording).
    static let intervalRun = Run(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        startDate: Date(timeIntervalSince1970: 1_740_200_000),
        endDate:   Date(timeIntervalSince1970: 1_740_202_600),
        distance: 5_200,
        duration: 2_600,
        isIndoor: false,
        calories: 420,
        averageHeartRate: 168,
        maxHeartRate: 194,
        averagePacePerKilometer: 500,
        totalElevationAscent: 10,
        totalElevationDescent: 9,
        splits: nil,
        workoutActivities: nil
    )

    // A run where the user paused mid-workout.
    // duration < endDate - startDate reflects the active-only time.
    static let runWithPause = Run(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        startDate: Date(timeIntervalSince1970: 1_740_300_000),
        endDate:   Date(timeIntervalSince1970: 1_740_303_000),
        distance: 7_500,
        duration: 2_700,           // 300s pause → duration < elapsed
        isIndoor: false,
        calories: 430,
        averageHeartRate: 155,
        maxHeartRate: 172,
        averagePacePerKilometer: 360,
        totalElevationAscent: 22,
        totalElevationDescent: 20,
        splits: nil,
        workoutActivities: nil
    )

    // A 5×1km interval run with workoutActivities populated.
    // Alternating work (1km @ 4:30/km) and recovery (250m easy jog).
    static let intervalRunWithActivities = Run(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        startDate: Date(timeIntervalSince1970: 1_740_400_000),
        endDate:   Date(timeIntervalSince1970: 1_740_401_750),
        distance: 6_000,
        duration: 1_750,
        isIndoor: false,
        calories: 520,
        averageHeartRate: 162,
        maxHeartRate: 182,
        averagePacePerKilometer: 292,
        totalElevationAscent: 12,
        totalElevationDescent: 10,
        splits: nil,
        workoutActivities: [
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_400_000),
                            endDate:   Date(timeIntervalSince1970: 1_740_400_270),
                            duration: 270, distance: 1000, averageHeartRate: 158, averagePace: 270, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_400_270),
                            endDate:   Date(timeIntervalSince1970: 1_740_400_370),
                            duration: 100, distance: 250, averageHeartRate: 142, averagePace: 400, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_400_370),
                            endDate:   Date(timeIntervalSince1970: 1_740_400_640),
                            duration: 270, distance: 1000, averageHeartRate: 163, averagePace: 270, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_400_640),
                            endDate:   Date(timeIntervalSince1970: 1_740_400_740),
                            duration: 100, distance: 250, averageHeartRate: 147, averagePace: 400, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_400_740),
                            endDate:   Date(timeIntervalSince1970: 1_740_401_010),
                            duration: 270, distance: 1000, averageHeartRate: 166, averagePace: 270, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_401_010),
                            endDate:   Date(timeIntervalSince1970: 1_740_401_110),
                            duration: 100, distance: 250, averageHeartRate: 150, averagePace: 400, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_401_110),
                            endDate:   Date(timeIntervalSince1970: 1_740_401_380),
                            duration: 270, distance: 1000, averageHeartRate: 168, averagePace: 270, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_401_380),
                            endDate:   Date(timeIntervalSince1970: 1_740_401_480),
                            duration: 100, distance: 250, averageHeartRate: 152, averagePace: 400, activityType: "running"),
            WorkoutActivity(startDate: Date(timeIntervalSince1970: 1_740_401_480),
                            endDate:   Date(timeIntervalSince1970: 1_740_401_750),
                            duration: 270, distance: 1000, averageHeartRate: 171, averagePace: 270, activityType: "running"),
        ]
    )
}
