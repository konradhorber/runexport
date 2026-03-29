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
  "exportDate": 1743200000.0,
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

All dates are Unix timestamps (seconds since epoch, floating-point). All distances are in **meters**, durations in **seconds**, heart rates in **bpm**, and elevations in **meters**. This matches HealthKit's native SI units exactly — no unit conversion is applied.

### `Run`

```json
{
  "id": "A1B2C3D4-E5F6-...",
  "startDate": 1743100000.0,
  "endDate": 1743103600.0,
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
| `startDate`               | number          | no       | Workout start, Unix timestamp |
| `endDate`                 | number          | no       | Workout end, Unix timestamp |
| `distance`                | number          | no       | Total distance in meters (`HKWorkout.totalDistance`) |
| `duration`                | number          | no       | Active duration in seconds (`HKWorkout.duration`) |
| `isIndoor`                | boolean         | no       | `true` for treadmill / indoor runs (`HKMetadataKeyIndoorWorkout`). When `true`, GPS route and splits will be absent and pace data comes from the watch accelerometer or GymKit — treat with caution |
| `calories`                | number          | yes      | Active energy burned in kcal (`activeEnergyBurned`). `null` if not recorded |
| `averageHeartRate`        | number          | yes      | Average heart rate in bpm over the workout. `null` if no HR sensor data |
| `maxHeartRate`            | number          | yes      | Maximum heart rate in bpm. `null` if no HR sensor data |
| `averagePacePerKilometer` | number          | yes      | `duration / (distance / 1000)` in seconds per km. `null` if distance is zero |
| `totalElevationAscent`    | number          | yes      | Total ascent in meters (`HKMetadataKeyElevationAscended`). `null` if not recorded (e.g. indoor) |
| `totalElevationDescent`   | number          | yes      | Total descent in meters (`HKMetadataKeyElevationDescended`). `null` if not recorded |
| `workoutEvents`           | array           | no       | Ordered list of `WorkoutEvent` objects. Empty array if none recorded. Use `.segment` events to identify interval boundaries |
| `splits`                  | array           | yes      | Per-km breakdown as `KilometerSplit` objects. `null` when no GPS route is available (indoor runs, or outdoor runs where location was not recorded) |

---

### `WorkoutEvent`

Mirrors `HKWorkoutEvent`. Events are in chronological order.

```json
{
  "type": "segment",
  "startDate": 1743100060.0,
  "endDate": 1743100360.0
}
```

| Field       | Type   | Description |
|-------------|--------|-------------|
| `type`      | string | Event type (see `WorkoutEventType` below) |
| `startDate` | number | Event start, Unix timestamp |
| `endDate`   | number | Event end, Unix timestamp |

#### `WorkoutEventType` values

| Value           | HealthKit source                | Meaning |
|-----------------|---------------------------------|---------|
| `pause`         | `.pause`                        | User manually paused the workout |
| `resume`        | `.resume`                       | User manually resumed |
| `lap`           | `.lap`                          | Manual or Auto Lap marker |
| `marker`        | `.marker`                       | Generic marker |
| `motionPaused`  | `.motionPaused`                 | Auto-pause triggered by lack of motion |
| `motionResumed` | `.motionResumed`                | Auto-pause cleared |
| `segment`       | `.segment`                      | **Interval boundary.** Emitted by Apple Watch when a workout uses an interval template. Consecutive pairs of `segment` events delimit individual work/recovery intervals — the interval runs from a segment's `startDate` to its `endDate` |
| `pauseDetected` | `.pauseDetected`                | System detected a pause |
| `resumeDetected`| `.resumeDetected`               | System detected a resume |

> **Interval detection:** Filter `workoutEvents` for `type == "segment"`. Each segment event covers exactly one interval period (work or recovery). Alternate segments correspond to alternating work/recovery phases. Only present when the workout was recorded using an interval template; `workoutEvents` will be empty for free-form runs.

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
├── RunTests.swift         # Unit tests for Run computed properties and JSON serialisation
└── APIClientTests.swift   # Unit tests for APIClient request logic (mocked network)
```
