import Testing
import Foundation
@testable import runexport

struct RunTests {
    func makeRun(distance: Double, duration: TimeInterval) -> Run {
        Run(
            id: UUID(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(duration),
            distance: distance,
            duration: duration,
            isIndoor: false,
            calories: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            averagePacePerKilometer: distance > 0 ? duration / (distance / 1000.0) : nil,
            totalElevationAscent: nil,
            totalElevationDescent: nil,
            workoutEvents: [],
            splits: nil
        )
    }

    @Test func distanceInKilometers() {
        let run = makeRun(distance: 5000, duration: 1800)
        #expect(run.distanceInKilometers == 5.0)
    }

    @Test func distanceInMiles() {
        let run = makeRun(distance: 1609.34, duration: 600)
        #expect(abs(run.distanceInMiles - 1.0) < 0.001)
    }

    @Test func pacePerKilometer() {
        // 5km in 25 minutes = 5:00/km
        let run = makeRun(distance: 5000, duration: 25 * 60)
        #expect(run.pacePerKilometer == 5 * 60)
    }

    @Test func pacePerMile() {
        // 1 mile in 8 minutes = 8:00/mi
        let run = makeRun(distance: 1609.34, duration: 8 * 60)
        #expect(abs(run.pacePerMile - 8 * 60) < 1)
    }

    @Test func paceIsZeroWhenNoDistance() {
        let run = makeRun(distance: 0, duration: 600)
        #expect(run.pacePerKilometer == 0)
        #expect(run.pacePerMile == 0)
    }

    @Test func averagePacePerKilometerIsNilWhenNoDistance() {
        let run = makeRun(distance: 0, duration: 600)
        #expect(run.averagePacePerKilometer == nil)
    }

    @Test func averagePacePerKilometerMatchesPacePerKilometer() {
        let run = makeRun(distance: 5000, duration: 25 * 60)
        #expect(run.averagePacePerKilometer == run.pacePerKilometer)
    }

    @Test func newFieldsSurviveJSONRoundTrip() throws {
        let original = Run(
            id: UUID(),
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 3600),
            distance: 10_000,
            duration: 3600,
            isIndoor: true,
            calories: 500,
            averageHeartRate: 155.0,
            maxHeartRate: 178.0,
            averagePacePerKilometer: 360,
            totalElevationAscent: 120.5,
            totalElevationDescent: 118.0,
            workoutEvents: [WorkoutEvent(type: .segment, startDate: Date(timeIntervalSince1970: 0), endDate: Date(timeIntervalSince1970: 300))],
            splits: [KilometerSplit(kilometer: 1, pace: 355, averageHeartRate: 150, elevationAscent: 10, elevationDescent: 5)]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Run.self, from: data)

        #expect(decoded.isIndoor == true)
        #expect(decoded.averageHeartRate == 155.0)
        #expect(decoded.maxHeartRate == 178.0)
        #expect(decoded.averagePacePerKilometer == 360)
        #expect(decoded.totalElevationAscent == 120.5)
        #expect(decoded.totalElevationDescent == 118.0)
        #expect(decoded.workoutEvents.first?.type == .segment)
        #expect(decoded.splits?.first?.kilometer == 1)
        #expect(decoded.splits?.first?.pace == 355)
        #expect(decoded.splits?.first?.averageHeartRate == 150)
    }
}
