# ASTHI-PROTECT App (Flutter)

Field screening app for ASHA workers: record a gait video, collect sensor-band
data, answer symptom questions, get an on-device OA risk report. Works fully
offline; saved screenings sync later (store & forward).

## How the code works

- `lib/main.dart` - app entry, opens the home screen.
- `lib/screens/home_screen.dart` - the 4-step screening flow (gait video,
  band, questions, report) plus the saved-screenings list with sync status.
- `lib/screens/gait_capture_screen.dart` - live camera preview, runs
  on-device pose detection (ML Kit) on every frame, draws the skeleton, and
  while recording turns each frame's landmarks into a FrameSample (knee/hip
  angles, trunk lean, ankle forward reach). Same angle math as the Python
  gait_pose_estimation module.
- `lib/services/gait_metrics.dart` - pure Dart, no Flutter imports. Angle
  math, smoothing, step (heel-strike) detection from ankle reach peaks, gait
  metrics (cadence, knee ROM per leg, asymmetry, trunk lean) and the heuristic
  screening flags. Ported from gait_analysis.py.
- `lib/screens/band_screen.dart` + `lib/services/ble_service.dart` - scans for
  a BLE device named ASTHI*, connects, subscribes to the data characteristic,
  and collects band samples (EMG RMS, IMU pitch, mic level) into a summary.
  The service/characteristic UUIDs and the 12-byte packet layout are
  placeholders - match them to the band firmware when it exists.
- `lib/screens/questionnaire_screen.dart` - 5 WOMAC-style symptom questions,
  0-4 scale, English/Hindi toggle. Add languages by extending the maps.
- `lib/services/risk_model.dart` - combines gait flags + questionnaire score
  into low/moderate/high risk with referral text. This is the heuristic
  stand-in for the TFLite fusion model from the deck; swap `assess` for a
  tflite_flutter interpreter call when the trained model exists.
- `lib/services/storage.dart` - SQLite (sqflite) store of every screening,
  with a synced flag for the store & forward queue. The actual upload to the
  ABDM/FHIR endpoint is not implemented yet (needs the endpoint spec).
- `lib/models/screening.dart` - the Screening record and band summary.

## Run it

This repo has `lib/` + `pubspec.yaml` only (no platform folders yet):

```
flutter create .
flutter pub get
flutter run
```

AndroidManifest needs CAMERA and BLUETOOTH_SCAN / BLUETOOTH_CONNECT
permissions; `flutter create .` generates the manifest, add them there.

## Test status

- gait_metrics.dart analyzed clean (dart analyze) and verified against
  synthetic walking data in the Dart VM: healthy walk recovers cadence 120.7
  spm with no flags; degraded gait triggers ROM + cadence flags.
- All 11 Dart files parse (dart format).
- NOT compiled or run as an app: no Flutter SDK, Android device, or BLE band
  was available here. Camera/pose, BLE, and SQLite paths are untested on
  hardware. UI needs a real device pass.
