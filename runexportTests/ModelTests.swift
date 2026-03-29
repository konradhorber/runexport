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

// MARK: - WorkoutEventType

// Tests that every event type encodes to a human-readable string and decodes back correctly.
// Using @Test(arguments:) with WorkoutEventType.allCases means Swift Testing runs this
// test once per case and reports each one individually — much better than a loop.
@Suite("WorkoutEventType") struct WorkoutEventTypeTests {

    @Test("all cases encode as their raw string name",
          arguments: WorkoutEventType.allCases)
    func encodesAsRawString(eventType: WorkoutEventType) throws {
        let event = WorkoutEvent(
            type: eventType,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 60)
        )
        let json = try JSONEncoder().encode(event)
        // Parse the raw JSON dictionary so we can inspect the "type" string directly
        let dict = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        #expect(dict["type"] as? String == eventType.rawValue)
    }

    @Test("all cases survive a JSON round-trip",
          arguments: WorkoutEventType.allCases)
    func jsonRoundTrip(eventType: WorkoutEventType) throws {
        let event = WorkoutEvent(
            type: eventType,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 60)
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(WorkoutEvent.self, from: data)
        #expect(decoded.type == eventType)
    }
}

// MARK: - WorkoutEvent

@Suite("WorkoutEvent") struct WorkoutEventTests {

    // Demonstrates filtering workoutEvents by type — the pattern a server would use
    // to extract interval boundaries from a run.
    @Test("segment events can be filtered from mixed workoutEvents") func filterSegments() {
        let segments = RunFixtures.intervalRun.workoutEvents.filter { $0.type == .segment }
        #expect(segments.count == 4) // 2 work + 2 recovery
    }

    @Test("non-segment events are absent from an interval run") func noNonSegmentEvents() {
        let nonSegments = RunFixtures.intervalRun.workoutEvents.filter { $0.type != .segment }
        #expect(nonSegments.isEmpty)
    }

    // Consecutive segment events should be back-to-back (no gaps or overlaps).
    @Test("segment events are contiguous") func segmentsAreContiguous() {
        let segments = RunFixtures.intervalRun.workoutEvents.filter { $0.type == .segment }
        for i in 1..<segments.count {
            #expect(segments[i].startDate == segments[i - 1].endDate)
        }
    }

    @Test("pause run has no segment events") func pauseRunHasNoSegments() {
        let segments = RunFixtures.runWithPause.workoutEvents.filter { $0.type == .segment }
        #expect(segments.isEmpty)
    }

    @Test("pause is followed by resume") func pauseFollowedByResume() {
        let events = RunFixtures.runWithPause.workoutEvents
        // try #require is like #expect but stops the test immediately if false —
        // use it for preconditions that make the rest of the test meaningless if they fail
        let pause  = try? #require(events.first { $0.type == .pause })
        let resume = try? #require(events.first { $0.type == .resume })
        if let pause, let resume {
            #expect(resume.startDate >= pause.endDate)
        }
    }
}

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

// MARK: - Run — intervals

@Suite("Run — intervals") struct RunIntervalTests {

    @Test("interval run has segment events") func hasSegmentEvents() {
        #expect(!RunFixtures.intervalRun.workoutEvents.isEmpty)
    }

    @Test("interval run has no splits (no GPS route recorded)") func noSplits() {
        // GPS is typically not stored for structured interval workouts on Apple Watch
        #expect(RunFixtures.intervalRun.splits == nil)
    }

    @Test("free-form run has no segment events") func freeFormNoSegments() {
        let segments = RunFixtures.outdoor5km.workoutEvents.filter { $0.type == .segment }
        #expect(segments.isEmpty)
    }

    // Verifying the work/recovery alternation expected by a server-side consumer:
    // even-indexed segments (0, 2, …) are work; odd-indexed (1, 3, …) are recovery.
    @Test("segment event durations reflect work/recovery pattern") func workRecoveryDurations() {
        let segments = RunFixtures.intervalRun.workoutEvents.filter { $0.type == .segment }
        let durations = segments.map { $0.endDate.timeIntervalSince($0.startDate) }

        // Work intervals in the fixture are 240s, recovery intervals are 300s
        #expect(durations[0] == 240) // work 1
        #expect(durations[1] == 300) // recovery 1
        #expect(durations[2] == 240) // work 2
        #expect(durations[3] == 300) // recovery 2
    }

    @Test("workout events survive JSON round-trip") func eventsRoundTrip() throws {
        let data = try JSONEncoder().encode(RunFixtures.intervalRun)
        let decoded = try JSONDecoder().decode(Run.self, from: data)
        #expect(decoded.workoutEvents.count == RunFixtures.intervalRun.workoutEvents.count)
        #expect(decoded.workoutEvents.first?.type == .segment)
    }
}
