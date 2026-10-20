import argparse
import csv
import json
import math
from dataclasses import dataclass, field

import numpy as np

LM = {
    "nose": 0,
    "left_shoulder": 11, "right_shoulder": 12,
    "left_elbow": 13, "right_elbow": 14,
    "left_wrist": 15, "right_wrist": 16,
    "left_hip": 23, "right_hip": 24,
    "left_knee": 25, "right_knee": 26,
    "left_ankle": 27, "right_ankle": 28,
    "left_heel": 29, "right_heel": 30,
    "left_foot_index": 31, "right_foot_index": 32,
}

MIN_VISIBILITY = 0.5


def angle_between(a, b, c):
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    c = np.asarray(c, dtype=float)
    ba = a - b
    bc = c - b
    denom = np.linalg.norm(ba) * np.linalg.norm(bc)
    if denom < 1e-9:
        return float("nan")
    cosang = np.clip(np.dot(ba, bc) / denom, -1.0, 1.0)
    return math.degrees(math.acos(cosang))


def _pt(landmarks, name):
    i = LM[name]
    return landmarks[i, 0], landmarks[i, 1]


def _visible(landmarks, names):
    return all(landmarks[LM[n], 3] >= MIN_VISIBILITY for n in names)


def joint_angles(landmarks):
    out = {}
    if _visible(landmarks, ("left_hip", "left_knee", "left_ankle")):
        out["knee_left"] = angle_between(_pt(landmarks, "left_hip"), _pt(landmarks, "left_knee"), _pt(landmarks, "left_ankle"))
    if _visible(landmarks, ("right_hip", "right_knee", "right_ankle")):
        out["knee_right"] = angle_between(_pt(landmarks, "right_hip"), _pt(landmarks, "right_knee"), _pt(landmarks, "right_ankle"))
    if _visible(landmarks, ("left_shoulder", "left_hip", "left_knee")):
        out["hip_left"] = angle_between(_pt(landmarks, "left_shoulder"), _pt(landmarks, "left_hip"), _pt(landmarks, "left_knee"))
    if _visible(landmarks, ("right_shoulder", "right_hip", "right_knee")):
        out["hip_right"] = angle_between(_pt(landmarks, "right_shoulder"), _pt(landmarks, "right_hip"), _pt(landmarks, "right_knee"))
    if _visible(landmarks, ("left_knee", "left_ankle", "left_foot_index")):
        out["ankle_left"] = angle_between(_pt(landmarks, "left_knee"), _pt(landmarks, "left_ankle"), _pt(landmarks, "left_foot_index"))
    if _visible(landmarks, ("right_knee", "right_ankle", "right_foot_index")):
        out["ankle_right"] = angle_between(_pt(landmarks, "right_knee"), _pt(landmarks, "right_ankle"), _pt(landmarks, "right_foot_index"))
    if _visible(landmarks, ("left_shoulder", "right_shoulder", "left_hip", "right_hip")):
        sx = (landmarks[LM["left_shoulder"], 0] + landmarks[LM["right_shoulder"], 0]) / 2
        sy = (landmarks[LM["left_shoulder"], 1] + landmarks[LM["right_shoulder"], 1]) / 2
        hx = (landmarks[LM["left_hip"], 0] + landmarks[LM["right_hip"], 0]) / 2
        hy = (landmarks[LM["left_hip"], 1] + landmarks[LM["right_hip"], 1]) / 2
        dx = sx - hx
        dy = sy - hy
        if abs(dx) + abs(dy) > 1e-9:
            out["trunk_lean"] = math.degrees(math.atan2(abs(dx), abs(dy)))
    return out


def moving_average(values, window=5):
    values = np.asarray(values, dtype=float)
    if len(values) < window or window < 2:
        return values.copy()
    kernel = np.ones(window) / window
    sm = np.convolve(values, kernel, mode="same")
    edge = window // 2
    for i in range(edge):
        sm[i] = values[: i + edge + 1].mean()
        sm[-(i + 1)] = values[-(i + edge + 1):].mean()
    return sm


def find_peaks(values, min_distance, min_prominence):
    values = np.asarray(values, dtype=float)
    peaks = []
    n = len(values)
    for i in range(1, n - 1):
        if values[i] >= values[i - 1] and values[i] > values[i + 1]:
            lo = max(0, i - min_distance)
            hi = min(n, i + min_distance + 1)
            left_min = values[lo:i + 1].min()
            right_min = values[i:hi].min()
            if values[i] - max(left_min, right_min) >= min_prominence:
                peaks.append(i)
    merged = []
    for p in peaks:
        if merged and p - merged[-1] < min_distance:
            if values[p] > values[merged[-1]]:
                merged[-1] = p
        else:
            merged.append(p)
    return merged


@dataclass
class FramePose:
    time_s: float
    landmarks: np.ndarray
    angles: dict = field(default_factory=dict)


def extract_poses(video_path, max_frames=None):
    import cv2
    import mediapipe as mp

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"cannot open video: {video_path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    poses = []
    raw = []
    with mp.solutions.pose.Pose(static_image_mode=False, model_complexity=1,
                                min_detection_confidence=0.5, min_tracking_confidence=0.5) as pose:
        idx = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if max_frames is not None and idx >= max_frames:
                break
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            res = pose.process(rgb)
            if res.pose_landmarks:
                lm = np.array([[p.x, p.y, p.z, p.visibility] for p in res.pose_landmarks.landmark], dtype=float)
                t = idx / fps
                poses.append(FramePose(time_s=t, landmarks=lm, angles=joint_angles(lm)))
                raw.append((idx, frame.copy(), lm))
            idx += 1
    cap.release()
    return poses, fps, raw


def series_from_poses(poses, key):
    times = []
    vals = []
    for p in poses:
        v = p.angles.get(key)
        if v is not None and not math.isnan(v):
            times.append(p.time_s)
            vals.append(v)
    return np.array(times), np.array(vals)


def detect_heel_strikes(poses):
    times = np.array([p.time_s for p in poses])
    strikes = {}
    for side in ("left", "right"):
        hip = LM[f"{side}_hip"]
        ankle = LM[f"{side}_ankle"]
        reach = []
        tt = []
        for p in poses:
            if p.landmarks[ankle, 3] >= MIN_VISIBILITY and p.landmarks[hip, 3] >= MIN_VISIBILITY:
                tt.append(p.time_s)
                reach.append(p.landmarks[ankle, 0] - p.landmarks[hip, 0])
        if len(reach) < 10:
            strikes[side] = np.array([])
            continue
        reach = moving_average(np.array(reach), 5)
        prom = max(0.02, 0.25 * (reach.max() - reach.min()))
        pk = find_peaks(reach, min_distance=max(3, int(len(reach) / max(1, (tt[-1] - tt[0])) * 0.4)), min_prominence=prom)
        strikes[side] = np.array([tt[i] for i in pk])
    return times, strikes


def cycle_rom(times, values, strikes):
    roms = []
    for a, b in zip(strikes[:-1], strikes[1:]):
        mask = (times >= a) & (times <= b)
        if mask.sum() >= 3:
            seg = values[mask]
            roms.append(float(seg.max() - seg.min()))
    return roms


def compute_metrics(poses, duration_s):
    metrics = {"duration_s": round(duration_s, 2), "frames_with_pose": len(poses)}
    times, strikes = detect_heel_strikes(poses)
    n_steps = int(len(strikes["left"]) + len(strikes["right"]))
    metrics["steps_left"] = len(strikes["left"])
    metrics["steps_right"] = len(strikes["right"])
    metrics["cadence_spm"] = round(n_steps / duration_s * 60.0, 1) if duration_s > 0 else None

    step_intervals = []
    for side in ("left", "right"):
        s = strikes[side]
        if len(s) > 1:
            step_intervals.extend((s[1:] - s[:-1]).tolist())
    if step_intervals:
        si = np.array(step_intervals)
        metrics["step_time_mean_s"] = round(float(si.mean()), 3)
        metrics["step_time_cv"] = round(float(si.std() / si.mean()), 3) if si.mean() > 0 else None

    knee_rom = {}
    for side in ("left", "right"):
        t, v = series_from_poses(poses, f"knee_{side}")
        if len(v) > 10 and len(strikes[side]) > 1:
            v = moving_average(v, 5)
            roms = cycle_rom(t, v, strikes[side])
            if roms:
                knee_rom[side] = round(float(np.mean(roms)), 1)
        elif len(v) > 10:
            knee_rom[side] = round(float(v.max() - v.min()), 1)
    if knee_rom:
        metrics["knee_rom_deg"] = knee_rom
        if "left" in knee_rom and "right" in knee_rom:
            l, r = knee_rom["left"], knee_rom["right"]
            metrics["knee_rom_asymmetry_pct"] = round(abs(l - r) / (0.5 * (l + r)) * 100.0, 1)

    for side in ("left", "right"):
        t, v = series_from_poses(poses, f"hip_{side}")
        if len(v) > 10:
            metrics[f"hip_rom_{side}_deg"] = round(float(v.max() - v.min()), 1)

    t, v = series_from_poses(poses, "trunk_lean")
    if len(v) > 0:
        metrics["trunk_lean_mean_deg"] = round(float(v.mean()), 1)
    return metrics


def risk_flags(metrics):
    flags = []
    rom = metrics.get("knee_rom_deg", {})
    for side, val in rom.items():
        if val < 45.0:
            flags.append(f"reduced knee range of motion ({side}: {val} deg)")
    asym = metrics.get("knee_rom_asymmetry_pct")
    if asym is not None and asym > 15.0:
        flags.append(f"left-right knee asymmetry {asym}%")
    cad = metrics.get("cadence_spm")
    if cad is not None and cad < 90:
        flags.append(f"low cadence ({cad} steps/min)")
    lean = metrics.get("trunk_lean_mean_deg")
    if lean is not None and lean > 10.0:
        flags.append(f"forward trunk lean ({lean} deg)")
    return flags


def write_csv(path, poses):
    keys = sorted({k for p in poses for k in p.angles})
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["time_s"] + keys)
        for p in poses:
            w.writerow([f"{p.time_s:.3f}"] + [f"{p.angles[k]:.2f}" if k in p.angles else "" for k in keys])


def write_annotated_video(path, raw, fps):
    import cv2
    import mediapipe as mp
    if not raw:
        return
    h, w = raw[0][1].shape[:2]
    writer = cv2.VideoWriter(path, cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    drawing = mp.solutions.drawing_utils
    styles = mp.solutions.drawing_styles
    connections = mp.solutions.pose.POSE_CONNECTIONS
    for _, frame, lm in raw:
        h, w = frame.shape[:2]
        pts = {i: (int(lm[i, 0] * w), int(lm[i, 1] * h)) for i in range(len(lm)) if lm[i, 3] >= MIN_VISIBILITY}
        for a, b in connections:
            if a in pts and b in pts:
                cv2.line(frame, pts[a], pts[b], (0, 255, 0), 2)
        for p in pts.values():
            cv2.circle(frame, p, 4, (0, 0, 255), -1)
        writer.write(frame)
    writer.release()


def analyze_video(video_path, csv_path=None, annotated_path=None, max_frames=None):
    poses, fps, raw = extract_poses(video_path, max_frames=max_frames)
    if not poses:
        raise RuntimeError("no pose detected in any frame")
    duration = poses[-1].time_s - poses[0].time_s
    metrics = compute_metrics(poses, duration)
    metrics["fps"] = round(fps, 2)
    flags = risk_flags(metrics)
    report = {
        "video": video_path,
        "metrics": metrics,
        "screening_flags": flags,
        "note": "Heuristic screening markers from monocular pose estimation. Not a diagnosis.",
    }
    if csv_path:
        write_csv(csv_path, poses)
    if annotated_path:
        write_annotated_video(annotated_path, raw, fps)
    return report


def main():
    ap = argparse.ArgumentParser(description="Gait pose estimation for ASTHI-PROTECT OA risk screening")
    ap.add_argument("--video", required=True)
    ap.add_argument("--out", default="report.json")
    ap.add_argument("--csv", default=None)
    ap.add_argument("--annotated", default=None)
    ap.add_argument("--max-frames", type=int, default=None)
    args = ap.parse_args()
    report = analyze_video(args.video, csv_path=args.csv, annotated_path=args.annotated, max_frames=args.max_frames)
    with open(args.out, "w") as f:
        json.dump(report, f, indent=2)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
