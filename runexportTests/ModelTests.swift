//
//  ModelTests.swift
//  runexportTests
//
// Tests for the Run, WorkoutEvent, KilometerSplit, and WorkoutEventType models.
//
// --- Swift Testing primer ---
//
// This project uses Swift Testing (introduced in Xcode 16), NOT the older XCTest.
// Key differences:
//
//   @Test            marks a function as a test case
//   @Suite           groups related tests into a named suite (shows up in the test navigator)
//   #expect(expr)    asserts that expr is true — prints both sides of the expression on failure
//   #expect(throws:) asserts that a call throws a specific error
//   try #require(x)  like #expect but stops the test immediately if it fails (use for preconditions)
//
// Parameterised tests:
//   @Test(arguments: someCollection)  runs the test once per element, reported separately
//
// Tests can be plain functions (no class/struct needed), but grouping them in a struct
// with @Suite keeps the test navigator tidy.
//

import Testing
import Foundation
@testable import runexport

// MARK: - KilometerSplit

@Suite("KilometerSplit") struct KilometerSplitTests {

    @Test("splits are numbered from 1 sequentially") func sequentialNumbering() {
        let splits = RunFixtures.outdoor5km.splits!
        for (index, split) in splits.enumerated() {
            #expect(split.kilometer == index + 1)
        }
    }

    @Test("split count matches expected km for distance") func splitCountMatchesDistance() {
        // 5 km run → 5 full-km splits
        let splits = RunFixtures.outdoor5km.splits!
        #expect(splits.count == 5)
    }

    @Test("nil elevation fields survive JSON round-trip as nil") func nilElevationRoundTrip() throws {
        let split = KilometerSplit(
            kilometer: 1,
            pace: 300,
            averageHeartRate: nil,
            elevationAscent: nil,
            elevationDescent: nil
        )
        let data = try JSONEncoder().encode(split)
        let decoded = try JSONDecoder().decode(KilometerSplit.self, from: data)
        #expect(decoded.averageHeartRate == nil)
        #expect(decoded.elevationAscent == nil)
        #expect(decoded.elevationDescent == nil)
    }

    @Test("pace is preserved exactly through JSON") func paceRoundTrip() throws {
        let split = KilometerSplit(kilometer: 3, pace: 312.5, averageHeartRate: 160, elevationAscent: 5, elevationDescent: nil)
        let data = try JSONEncoder().encode(split)
        let decoded = try JSONDecoder().decode(KilometerSplit.self, from: data)
        #expect(decoded.pace == 312.5)
    }

    // A split where one elevation direction is nil and the other is not
    // verifies that the two fields are independent and don't interfere.
    @Test("ascent and descent are independent") func ascentDescentIndependent() throws {
        let split = KilometerSplit(kilometer: 1, pace: 300, averageHeartRate: nil, elevationAscent: 20, elevationDescent: nil)
        let data = try JSONEncoder().encode(split)
        let decoded = try JSONDecoder().decode(KilometerSplit.self, from: data)
        #expect(decoded.elevationAscent == 20)
        #expect(decoded.elevationDescent == nil)
    }
}

// MARK: - Run — indoor

@Suite("Run — indoor") struct RunIndoorTests {

    @Test("isIndoor is true for treadmill fixture") func isIndoorTrue() {
        #expect(RunFixtures.indoorTreadmill.isIndoor == true)
    }

    @Test("indoor run has no splits") func noSplits() {
        #expect(RunFixtures.indoorTreadmill.splits == nil)
    }

    @Test("indoor run has no elevation data") func noElevation() {
        #expect(RunFixtures.indoorTreadmill.totalElevationAscent == nil)
        #expect(RunFixtures.indoorTreadmill.totalElevationDescent == nil)
    }

    @Test("outdoor run has splits") func outdoorHasSplits() {
        #expect(RunFixtures.outdoor5km.isIndoor == false)
        #expect(RunFixtures.outdoor5km.splits != nil)
    }

    @Test("isIndoor survives JSON round-trip") func isIndoorRoundTrip() throws {
        let data = try JSONEncoder().encode(RunFixtures.indoorTreadmill)
        let decoded = try JSONDecoder().decode(Run.self, from: data)
        #expect(decoded.isIndoor == true)
    }
}

// MARK: - WorkoutActivity

@Suite("WorkoutActivity") struct WorkoutActivityTests {

    let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func makeActivity(distance: Double? = 1000, hr: Double? = 165, activityType: String = "running") -> WorkoutActivity {
        WorkoutActivity(
            startDate: Date(timeIntervalSince1970: 1_740_200_000),
            endDate:   Date(timeIntervalSince1970: 1_740_200_270),
            duration: 270,
            distance: distance,
            averageHeartRate: hr,
            averagePace: distance.flatMap { d in d > 0 ? 270 / (d / 1000) : nil },
            activityType: activityType
        )
    }

    @Test("survives JSON round-trip") func jsonRoundTrip() throws {
        let data = try encoder.encode(makeActivity())
        let decoded = try decoder.decode(WorkoutActivity.self, from: data)
        #expect(decoded.duration == 270)
        #expect(decoded.distance == 1000)
        #expect(decoded.averageHeartRate == 165)
        #expect(decoded.averagePace == 270)
        #expect(decoded.activityType == "running")
    }

    @Test("nil optional fields survive round-trip as nil") func nilFieldsRoundTrip() throws {
        let activity = makeActivity(distance: nil, hr: nil)
        let data = try encoder.encode(activity)
        let decoded = try decoder.decode(WorkoutActivity.self, from: data)
        #expect(decoded.distance == nil)
        #expect(decoded.averageHeartRate == nil)
        #expect(decoded.averagePace == nil)
    }

    @Test("activityType string is preserved") func activityTypePreserved() throws {
        let data = try encoder.encode(makeActivity(activityType: "walking"))
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["activityType"] as? String == "walking")
    }

    @Test("dates encode as ISO 8601") func datesAreISO8601() throws {
        let data = try encoder.encode(makeActivity())
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(dict["startDate"] is String)
        #expect(dict["endDate"] is String)
    }

    @Test("run with activities survives JSON round-trip") func runWithActivitiesRoundTrip() throws {
        let run = RunFixtures.intervalRunWithActivities
        let data = try encoder.encode(run)
        let decoded = try decoder.decode(Run.self, from: data)
        #expect(decoded.workoutActivities?.count == run.workoutActivities?.count)
        #expect(decoded.workoutActivities?.first?.activityType == "running")
        #expect(decoded.workoutActivities?.first?.distance == 1000)
    }

    @Test("plain run has nil workoutActivities") func plainRunHasNilActivities() throws {
        #expect(RunFixtures.outdoor5km.workoutActivities == nil)
    }

    @Test("interval run with activities has alternating work and recovery") func alternatingPhases() {
        let activities = RunFixtures.intervalRunWithActivities.workoutActivities!
        // Work intervals: faster pace; recovery: slower pace
        let paces = activities.compactMap { $0.averagePace }
        let workPaces = paces.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        let recoveryPaces = paces.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
        #expect(workPaces.allSatisfy { $0 < 300 })     // work: sub-5:00/km
        #expect(recoveryPaces.allSatisfy { $0 > 300 }) // recovery: above 5:00/km
    }
}

// MARK: - Run — intervals

@Suite("Run — intervals") struct RunIntervalTests {

    @Test("interval run without activities has nil workoutActivities") func noActivities() {
        #expect(RunFixtures.intervalRun.workoutActivities == nil)
    }

    @Test("interval run has no splits when no GPS route recorded") func noSplits() {
        #expect(RunFixtures.intervalRun.splits == nil)
    }

    @Test("plain run has no workoutActivities") func plainRunNoActivities() {
        #expect(RunFixtures.outdoor5km.workoutActivities == nil)
    }
}
