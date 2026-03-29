import Testing
import Foundation
@testable import runexport

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// Serialized prevents parallel execution so the shared static handler isn't overwritten mid-test
@MainActor
@Suite(.serialized)
struct APIClientTests {
    let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }()

    func makeRun(averageHeartRate: Double? = nil) -> Run {
        Run(
            id: UUID(),
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 3600),
            distance: 10_000,
            duration: 3600,
            isIndoor: false,
            calories: 500,
            averageHeartRate: averageHeartRate,
            maxHeartRate: nil,
            averagePacePerKilometer: 360,
            totalElevationAscent: nil,
            totalElevationDescent: nil,
            splits: nil,
            workoutActivities: nil
        )
    }

    func makeResponse(statusCode: Int, body: [String: Any]) throws -> (HTTPURLResponse, Data) {
        let url = URL(string: Config.serverBaseURL + "/runs")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        let data = try JSONSerialization.data(withJSONObject: body)
        return (response, data)
    }

    // URLSession converts httpBody to a stream internally inside URLProtocol
    func readBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: 1024)
            if read > 0 { data.append(buffer, count: read) }
        }
        return data
    }

    @Test func exportRunsPostsToCorrectURL() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.handler = { request in
            capturedRequest = request
            return try self.makeResponse(statusCode: 200, body: ["success": true, "runsProcessed": 1])
        }

        let client = APIClient(session: session)
        _ = try await client.exportRuns([makeRun()])

        #expect(capturedRequest?.url?.absoluteString == Config.serverBaseURL + "/runs")
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func exportRunsDecodesResponse() async throws {
        MockURLProtocol.handler = { _ in
            try self.makeResponse(statusCode: 200, body: ["success": true, "runsProcessed": 3])
        }

        let client = APIClient(session: session)
        let response = try await client.exportRuns([makeRun()])

        #expect(response.success == true)
        #expect(response.runsProcessed == 3)
    }

    @Test func exportRunsThrowsOnServerError() async throws {
        MockURLProtocol.handler = { _ in
            try self.makeResponse(statusCode: 500, body: [:])
        }

        let client = APIClient(session: session)
        await #expect(throws: APIError.serverError(statusCode: 500)) {
            try await client.exportRuns([self.makeRun()])
        }
    }

    @Test func exportRunsEncodesAllRuns() async throws {
        var capturedBody: RunExportRequest?
        MockURLProtocol.handler = { request in
            if let data = self.readBody(from: request) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                capturedBody = try decoder.decode(RunExportRequest.self, from: data)
            }
            return try self.makeResponse(statusCode: 200, body: ["success": true, "runsProcessed": 2])
        }

        let client = APIClient(session: session)
        _ = try await client.exportRuns([makeRun(), makeRun()])

        #expect(capturedBody?.runs.count == 2)
    }

    @Test func exportRunsPayloadIncludesHeartRate() async throws {
        var capturedBody: RunExportRequest?
        MockURLProtocol.handler = { request in
            if let data = self.readBody(from: request) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                capturedBody = try decoder.decode(RunExportRequest.self, from: data)
            }
            return try self.makeResponse(statusCode: 200, body: ["success": true, "runsProcessed": 1])
        }

        let client = APIClient(session: session)
        _ = try await client.exportRuns([makeRun(averageHeartRate: 155.0)])

        #expect(capturedBody?.runs.first?.averageHeartRate == 155.0)
    }
}
