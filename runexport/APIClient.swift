//
//  APIClient.swift
//  runexport
//
//  Created by Konrad on 08.03.26.
//

import Foundation

actor APIClient {
    // TODO: Configure your server URL
    private let baseURL = Config.serverBaseURL
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    // POST runs to server
    func exportRuns(_ runs: [Run]) async throws -> ExportResponse {
        guard let url = URL(string: "\(baseURL)/runs") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // TODO: Add authentication if needed
        // request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let exportRequest = RunExportRequest(
            runs: runs,
            deviceId: await getDeviceIdentifier(),
            exportDate: Date()
        )
        
        request.httpBody = try JSONEncoder().encode(exportRequest)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let exportResponse = try JSONDecoder().decode(ExportResponse.self, from: data)
        return exportResponse
    }
    
    // Get persistent device identifier
    private func getDeviceIdentifier() async -> String {
        // Use a persistent identifier
        if let identifier = UserDefaults.standard.string(forKey: "deviceIdentifier") {
            return identifier
        }
        
        let newIdentifier = UUID().uuidString
        UserDefaults.standard.set(newIdentifier, forKey: "deviceIdentifier")
        return newIdentifier
    }
}

struct ExportResponse: Codable {
    let success: Bool
    let runsProcessed: Int
    let message: String?
}

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .encodingError:
            return "Failed to encode data"
        }
    }
}
