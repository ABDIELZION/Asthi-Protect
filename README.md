# ASTHI-PROTECT

Offline, AI-assisted osteoarthritis (OA) risk screening for field use by ASHA
workers - Smart India Hackathon 2026, Problem Statement SIH26004 (MDoNER,
North Eastern Region). Team Koraaxiom (Team ID 163135).

Screening tool, not a diagnostic device. High-risk results are referred to a
PHC for clinical evaluation.

## System

1. Phone camera records a short side-view gait video.
2. Wearable tri-band (thigh, calf, hip) captures EMG, IMU motion and joint
   sounds over BLE - custom flex PCBs, TI ADS1292 AFE, Bosch BNO085, MEMS mic.
3. Guided multilingual symptom questions (WOMAC-style).
4. On-device AI fuses all three into an OA risk report with referral advice.
   Fully offline; records sync (store & forward) when connectivity returns.

## Repo layout

- `cad/` - STEP models of the wearable band chassis (Lower_Chassis,
  Upper_Chassis).
- `gait_pose_estimation/` - Python gait analysis: MediaPipe Pose on gait
  video, joint angles, gait metrics, screening flags. See its README.
- `app/` - Flutter screening app: gait capture with on-device pose detection,
  BLE band link, multilingual questionnaire, risk report, offline SQLite
  store. See its README.

## Stack

MediaPipe Pose / ML Kit, TensorFlow Lite (planned fusion model), Flutter,
SQLite, BLE. Hardware: custom rigid-flex PCB, ADS1292, BNO085, MEMS mic,
snap EMG electrodes.
