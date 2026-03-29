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
        workoutEvents: [],
        splits: [
            KilometerSplit(kilometer: 1, pace: 305, averageHeartRate: 154, elevationAscent: 12,   elevationDescent: nil),
            KilometerSplit(kilometer: 2, pace: 310, averageHeartRate: 161, elevationAscent: nil,  elevationDescent: 8),
            KilometerSplit(kilometer: 3, pace: 318, averageHeartRate: 165, elevationAscent: 22,   elevationDescent: nil),
            KilometerSplit(kilometer: 4, pace: 308, averageHeartRate: 167, elevationAscent: nil,  elevationDescent: 15),
            KilometerSplit(kilometer: 5, pace: 319, averageHeartRate: 170, elevationAscent: 14,   elevationDescent: 22),
        ]
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
        workoutEvents: [],
        splits: nil                // no GPS route
    )

    // An outdoor interval session recorded with the Apple Watch interval template.
    // workoutEvents contains .segment events marking each work/recovery period.
    // Segments alternate: work → recovery → work → recovery.
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
        workoutEvents: [
            // work 1: 4:00/km effort for 1 km
            WorkoutEvent(type: .segment,
                         startDate: Date(timeIntervalSince1970: 1_740_200_060),
                         endDate:   Date(timeIntervalSince1970: 1_740_200_300)),
            // recovery 1: easy jog for 5 min
            WorkoutEvent(type: .segment,
                         startDate: Date(timeIntervalSince1970: 1_740_200_300),
                         endDate:   Date(timeIntervalSince1970: 1_740_200_600)),
            // work 2
            WorkoutEvent(type: .segment,
                         startDate: Date(timeIntervalSince1970: 1_740_200_600),
                         endDate:   Date(timeIntervalSince1970: 1_740_200_840)),
            // recovery 2
            WorkoutEvent(type: .segment,
                         startDate: Date(timeIntervalSince1970: 1_740_200_840),
                         endDate:   Date(timeIntervalSince1970: 1_740_201_140)),
        ],
        splits: nil
    )

    // A run where the user paused and resumed mid-workout.
    // workoutEvents contains .pause / .resume rather than .segment.
    static let runWithPause = Run(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        startDate: Date(timeIntervalSince1970: 1_740_300_000),
        endDate:   Date(timeIntervalSince1970: 1_740_303_000),
        distance: 7_500,
        duration: 2_700,
        isIndoor: false,
        calories: 430,
        averageHeartRate: 155,
        maxHeartRate: 172,
        averagePacePerKilometer: 360,
        totalElevationAscent: 22,
        totalElevationDescent: 20,
        workoutEvents: [
            WorkoutEvent(type: .pause,
                         startDate: Date(timeIntervalSince1970: 1_740_301_200),
                         endDate:   Date(timeIntervalSince1970: 1_740_301_500)),
            WorkoutEvent(type: .resume,
                         startDate: Date(timeIntervalSince1970: 1_740_301_500),
                         endDate:   Date(timeIntervalSince1970: 1_740_301_500)),
        ],
        splits: nil
    )
}
