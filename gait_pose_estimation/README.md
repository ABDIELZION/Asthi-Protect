# Gait Pose Estimation - ASTHI-PROTECT

Camera-side half of the screening system. Takes a side-view gait video from a
phone camera, finds the person's body joints in every frame, and turns that
into gait numbers an OA risk model can use.

## How the code works

`gait_analysis.py`, top to bottom:

- `angle_between(a, b, c)` - the angle at joint `b` formed by points a-b-c,
  in degrees. A straight leg reads 180.
- `joint_angles(landmarks)` - for one frame, computes knee, hip and ankle
  angles for both legs, plus trunk lean (shoulders vs hips against vertical).
  MediaPipe gives 33 body landmarks with a visibility score; any angle using a
  landmark below 0.5 visibility is skipped instead of guessed.
- `moving_average` / `find_peaks` - small signal helpers. Smoothing removes
  frame-to-frame jitter; peak finding locates steps in the ankle motion.
- `extract_poses(video)` - runs MediaPipe Pose on every frame and collects the
  per-frame angles.
- `detect_heel_strikes(poses)` - a step lands when that foot's ankle is at its
  furthest point in front of the hip, so peaks in (ankle.x - hip.x) per side
  give the step times for each leg.
- `compute_metrics(poses)` - from step times and angle series: cadence
  (steps/min), step-time mean and variability, knee range of motion per leg
  (per gait cycle where cycles were found), left/right knee asymmetry %, hip
  ROM, mean trunk lean.
- `risk_flags(metrics)` - heuristic screening flags: knee ROM under 45 deg,
  left/right asymmetry over 15%, cadence under 90 spm, trunk lean over 10 deg.
  These are screening hints, not a diagnosis.
- Outputs: a JSON report (`--out`), per-frame angles as CSV (`--csv`), and an
  annotated video with the skeleton drawn on (`--annotated`).

## Run it

```
pip install -r requirements.txt
python gait_analysis.py --video gait.mp4 --out report.json --csv angles.csv --annotated annotated.mp4
```

Film side-on, full body in frame, plain background if possible.

## Tests

```
python -m unittest test_gait_analysis
```

Unit tests cover the angle math, peak finding, and the full metric pipeline on
a synthetic walking sequence. Verified end-to-end on a real side-view walking
video (pose tracked in 240/240 frames, cadence 105 spm, knee ROM 38.6/46.3 deg,
trunk lean 1.1 deg). Not yet tested on phone-camera field footage.
