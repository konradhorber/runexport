# runexport

iOS app that reads running workouts from HealthKit and POSTs them as JSON to a local server.

## Setup

1. Copy the config template and set your server's local IP:
   ```bash
   cp runexport/Config.swift.example runexport/Config.swift
   ```
   Then edit `Config.swift`:
   ```swift
   enum Config {
       static let serverBaseURL = "http://192.168.x.x:3000/api"
   }
   ```

2. Open `runexport.xcodeproj` in Xcode, set your development team under **Signing & Capabilities**, and run on a physical iPhone (HealthKit does not work in the simulator).

3. Start your local server and make sure your phone and Mac are on the same Wi-Fi network.

## API

The app sends a `POST` to `/api/runs` with `Content-Type: application/json`.

### Request body

```json
{
  "deviceId": "string",
  "exportDate": 1234567890,
  "runs": [
    {
      "id": "uuid",
      "startDate": 1234567890,
      "endDate": 1234567890,
      "distance": 10000.0,
      "duration": 3600.0,
      "calories": 500.0,
      "averageHeartRate": null,
      "route": [
        {
          "latitude": 47.1,
          "longitude": 8.5,
          "altitude": 450.0,
          "timestamp": 1234567890
        }
      ]
    }
  ]
}
```

Dates are Unix timestamps. `distance` is in meters, `duration` in seconds, `calories` in kcal.

### Expected response

```json
{
  "success": true,
  "runsProcessed": 5,
  "message": "optional string"
}
```

## Project structure

```
runexport/
├── Config.swift.example   # Copy to Config.swift and set your server URL (gitignored)
├── Run.swift              # Data models (Run, LocationPoint, RunExportRequest)
├── HealthKitManager.swift # Fetches workouts and GPS routes from HealthKit
├── APIClient.swift        # POSTs runs to the server
└── ContentView.swift      # UI

runexportTests/
├── RunTests.swift         # Unit tests for Run computed properties
└── APIClientTests.swift   # Unit tests for APIClient request logic (mocked network)
```
