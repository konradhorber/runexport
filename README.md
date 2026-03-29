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

`POST /api/runs` — `Content-Type: application/json`

### Request

```json
{
  "deviceId": "A1B2C3D4-...",
  "exportDate": "2025-03-28T14:00:00Z",
  "runs": [ <Run>, ... ]
}
```

| Field        | Type   | Description                              |
|--------------|--------|------------------------------------------|
| `deviceId`   | string | Persistent UUID identifying this device  |
| `exportDate` | number | Unix timestamp of the export             |
| `runs`       | array  | Array of `Run` objects (see below)       |

### Response

```json
{
  "success": true,
  "runsProcessed": 5,
  "message": "optional string"
}
```

---

## Data model

All dates are **ISO 8601 strings** in UTC (e.g. `"2025-03-27T10:00:00Z"`), parseable by `new Date(str)` in JavaScript and `Date(iso8601: str)` in Swift. All distances are in **meters**, durations in **seconds**, heart rates in **bpm**, and elevations in **meters**. This matches HealthKit's native SI units exactly — no unit conversion is applied.

### `Run`

```json
{
  "id": "A1B2C3D4-E5F6-...",
  "startDate": "2025-03-27T10:00:00Z",
  "endDate": "2025-03-27T11:00:00Z",
  "distance": 10234.5,
  "duration": 3541.0,
  "isIndoor": false,
  "calories": 612.0,
  "averageHeartRate": 158.0,
  "maxHeartRate": 181.0,
  "averagePacePerKilometer": 346.1,
  "totalElevationAscent": 84.2,
  "totalElevationDescent": 81.7,
  "workoutEvents": [ <WorkoutEvent>, ... ],
  "splits": [ <KilometerSplit>, ... ]
}
```

| Field                     | Type            | Nullable | Description |
|---------------------------|-----------------|----------|-------------|
| `id`                      | string (UUID)   | no       | HealthKit workout UUID — stable across exports |
| `startDate`               | string (ISO 8601) | no     | Workout start, UTC |
| `endDate`                 | string (ISO 8601) | no     | Workout end, UTC |
| `distance`                | number          | no       | Total distance in meters (`HKWorkout.totalDistance`) |
| `duration`                | number          | no       | Active duration in seconds (`HKWorkout.duration`) |
| `isIndoor`                | boolean         | no       | `true` for treadmill / indoor runs (`HKMetadataKeyIndoorWorkout`). When `true`, GPS route and splits will be absent and pace data comes from the watch accelerometer or GymKit — treat with caution |
| `calories`                | number          | yes      | Active energy burned in kcal (`activeEnergyBurned`). `null` if not recorded |
| `averageHeartRate`        | number          | yes      | Average heart rate in bpm over the workout. `null` if no HR sensor data |
| `maxHeartRate`            | number          | yes      | Maximum heart rate in bpm. `null` if no HR sensor data |
| `averagePacePerKilometer` | number          | yes      | `duration / (distance / 1000)` in seconds per km. `null` if distance is zero |
| `totalElevationAscent`    | number          | yes      | Total ascent in meters (`HKMetadataKeyElevationAscended`). `null` if not recorded (e.g. indoor) |
| `totalElevationDescent`   | number          | yes      | Total descent in meters (`HKMetadataKeyElevationDescended`). `null` if not recorded |
| `splits`                  | array           | yes      | Per-km breakdown as `KilometerSplit` objects. `null` when no GPS route is available (indoor runs, or outdoor runs where location was not recorded) |
| `workoutActivities`       | array           | yes      | Per-phase breakdown as `WorkoutActivity` objects. `null` for plain runs. Use this to identify interval work/recovery phases |

---

### `WorkoutActivity`

Per-phase breakdown of a structured workout. Populated from `HKWorkout.workoutActivities` (iOS 16+). Each entry represents one step in the workout — for an interval run this gives one entry per work interval and one per recovery, in order. `null` for plain runs with no template structure.

```json
{
  "startDate": "2026-03-26T16:51:25Z",
  "endDate": "2026-03-26T16:55:55Z",
  "duration": 270.0,
  "distance": 1000.0,
  "averageHeartRate": 165.0,
  "averagePace": 270.0,
  "activityType": "running"
}
```

| Field              | Type              | Nullable | Description |
|--------------------|-------------------|----------|-------------|
| `startDate`        | string (ISO 8601) | no       | Phase start, UTC |
| `endDate`          | string (ISO 8601) | no       | Phase end, UTC |
| `duration`         | number            | no       | Phase duration in seconds |
| `distance`         | number            | yes      | Distance covered in meters. `null` if no distance data for this phase |
| `averageHeartRate` | number            | yes      | Average HR in bpm during this phase. `null` if no HR data |
| `averagePace`      | number            | yes      | Seconds per km. `null` if `distance` is unavailable |
| `activityType`     | string            | no       | `"running"`, `"walking"`, or `"other(N)"` where N is the raw HealthKit activity type integer |

> **Interval detection:** For interval runs, `workoutActivities` is the authoritative source of interval structure. Each alternating entry is a work/recovery phase — distinguish them by `averagePace` or `averageHeartRate`. For plain runs this field contains a single entry covering the whole workout.

---

### `KilometerSplit`

One entry per km of GPS-tracked distance. The final entry covers a partial km if the run does not end exactly on a km boundary, with `pace` normalised to seconds/km.

```json
{
  "kilometer": 1,
  "pace": 342.8,
  "averageHeartRate": 154.0,
  "elevationAscent": 12.3,
  "elevationDescent": 4.1
}
```

| Field              | Type   | Nullable | Description |
|--------------------|--------|----------|-------------|
| `kilometer`        | int    | no       | 1-based km index |
| `pace`             | number | no       | Seconds per km for this split. For full km splits this is simply the elapsed time. For the partial final split it is normalised: `elapsed_seconds / (partial_distance_m / 1000)` |
| `averageHeartRate` | number | yes      | Average HR in bpm during this km. `null` if no HR data for the period |
| `elevationAscent`  | number | yes      | Meters gained in this km from GPS altitude. `null` if net gain is zero or negative |
| `elevationDescent` | number | yes      | Meters lost in this km from GPS altitude. `null` if net loss is zero or negative |

---

## Project structure

```
runexport/
├── Config.swift.example   # Copy to Config.swift and set your server URL (gitignored)
├── Run.swift              # Data models: Run, WorkoutEvent, KilometerSplit
├── HealthKitManager.swift # Fetches workouts, GPS routes, and heart rate from HealthKit
├── APIClient.swift        # POSTs runs to the server
└── ContentView.swift      # UI

runexportTests/
├── TestFixtures.swift     # Mock Run objects shared across test suites
├── ModelTests.swift       # Tests for Run, KilometerSplit, WorkoutActivity models
├── RunTests.swift         # Tests for Run computed properties and JSON serialisation
└── APIClientTests.swift   # Tests for APIClient request logic (mocked network)
```
