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
            calories: nil,
            averageHeartRate: nil
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
}
