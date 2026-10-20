import math
import unittest

import numpy as np

import gait_analysis as ga


def make_landmarks():
    lm = np.zeros((33, 4), dtype=float)
    lm[:, 3] = 1.0
    return lm


def set_side(lm, side, hip, knee, ankle, foot, shoulder):
    lm[ga.LM[f"{side}_hip"], 0:2] = hip
    lm[ga.LM[f"{side}_knee"], 0:2] = knee
    lm[ga.LM[f"{side}_ankle"], 0:2] = ankle
    lm[ga.LM[f"{side}_foot_index"], 0:2] = foot
    lm[ga.LM[f"{side}_shoulder"], 0:2] = shoulder


class TestAngles(unittest.TestCase):
    def test_straight_leg_is_180(self):
        self.assertAlmostEqual(ga.angle_between((0, 1), (0, 0), (0, -1)), 180.0, places=5)

    def test_right_angle(self):
        self.assertAlmostEqual(ga.angle_between((1, 0), (0, 0), (0, 1)), 90.0, places=5)

    def test_degenerate_returns_nan(self):
        self.assertTrue(math.isnan(ga.angle_between((0, 0), (0, 0), (1, 1))))

    def test_joint_angles_known_pose(self):
        lm = make_landmarks()
        set_side(lm, "left", hip=(0.5, 0.5), knee=(0.5, 0.7), ankle=(0.5, 0.9),
                 foot=(0.56, 0.93), shoulder=(0.5, 0.3))
        set_side(lm, "right", hip=(0.5, 0.5), knee=(0.5, 0.7), ankle=(0.55, 0.87),
                 foot=(0.6, 0.9), shoulder=(0.5, 0.3))
        ang = ga.joint_angles(lm)
        self.assertAlmostEqual(ang["knee_left"], 180.0, places=3)
        self.assertAlmostEqual(ang["hip_left"], 180.0, places=3)
        self.assertLess(ang["knee_right"], 180.0)
        self.assertAlmostEqual(ang["trunk_lean"], 0.0, places=3)

    def test_low_visibility_skips_angle(self):
        lm = make_landmarks()
        lm[ga.LM["left_knee"], 3] = 0.1
        set_side(lm, "left", hip=(0.5, 0.5), knee=(0.5, 0.7), ankle=(0.5, 0.9),
                 foot=(0.56, 0.93), shoulder=(0.5, 0.3))
        ang = ga.joint_angles(lm)
        self.assertNotIn("knee_left", ang)


class TestSignalHelpers(unittest.TestCase):
    def test_moving_average_smooths(self):
        v = np.array([0.0] * 10 + [10.0] * 10)
        sm = ga.moving_average(v, 5)
        self.assertLess(sm[9], 10.0)
        self.assertAlmostEqual(sm[15], 10.0, places=5)

    def test_find_peaks(self):
        t = np.linspace(0, 4 * np.pi, 200)
        v = np.sin(t)
        peaks = ga.find_peaks(v, min_distance=30, min_prominence=0.5)
        self.assertEqual(len(peaks), 2)


class TestGaitPipeline(unittest.TestCase):
    def synthetic_walk(self, n_frames=180, fps=30.0, step_hz=1.0):
        poses = []
        for i in range(n_frames):
            t = i / fps
            lm = make_landmarks()
            phase_l = 2 * np.pi * step_hz * t
            phase_r = phase_l + np.pi
            cx = 0.5
            lm[ga.LM["left_shoulder"], 0:2] = (cx - 0.02, 0.30)
            lm[ga.LM["right_shoulder"], 0:2] = (cx + 0.02, 0.30)
            for side, ph in (("left", phase_l), ("right", phase_r)):
                hip = np.array([cx, 0.55])
                knee_bend = 0.5 * (1 - np.cos(ph))
                thigh_len = 0.18
                shank_len = 0.18
                thigh_ang = -0.5 * np.sin(ph)
                knee = hip + thigh_len * np.array([np.sin(thigh_ang), np.cos(thigh_ang)])
                knee_lift = 0.10 * max(0.0, np.sin(ph))
                shank_ang = thigh_ang + 0.9 * max(0.0, np.sin(ph))
                ankle = knee + shank_len * np.array([np.sin(shank_ang), np.cos(shank_ang)]) - np.array([0, knee_lift])
                foot = ankle + np.array([0.06, 0.02])
                lm[ga.LM[f"{side}_hip"], 0:2] = hip
                lm[ga.LM[f"{side}_knee"], 0:2] = knee
                lm[ga.LM[f"{side}_ankle"], 0:2] = ankle
                lm[ga.LM[f"{side}_foot_index"], 0:2] = foot
            angles = ga.joint_angles(lm)
            poses.append(ga.FramePose(time_s=t, landmarks=lm, angles=angles))
        return poses, n_frames / fps

    def test_cadence_and_symmetry(self):
        poses, duration = self.synthetic_walk()
        m = ga.compute_metrics(poses, duration)
        self.assertIsNotNone(m["cadence_spm"])
        self.assertAlmostEqual(m["cadence_spm"], 120.0, delta=15.0)
        self.assertGreaterEqual(m["steps_left"], 3)
        self.assertGreaterEqual(m["steps_right"], 3)
        self.assertIn("knee_rom_deg", m)
        self.assertLess(m["knee_rom_asymmetry_pct"], 15.0)
        self.assertEqual(ga.risk_flags(m), [])

    def test_flags_on_bad_gait(self):
        poses, duration = self.synthetic_walk(step_hz=0.6)
        for p in poses:
            if "knee_right" in p.angles:
                p.angles["knee_right"] = 170.0
        m = ga.compute_metrics(poses, duration)
        flags = ga.risk_flags(m)
        self.assertTrue(any("asymmetry" in f or "range of motion" in f for f in flags))
        self.assertTrue(any("cadence" in f for f in flags))


if __name__ == "__main__":
    unittest.main()
