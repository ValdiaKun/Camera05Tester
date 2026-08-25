# Camera05Tester

A focused iOS diagnostic app for determining whether an iPhone 11 Ultra-Wide 0.5× camera is functioning.

## Test sequence

1. Detect `.builtInUltraWideCamera`.
2. Start an `AVCaptureSession`.
3. Confirm video frames arrive.
4. Confirm at least one sampled frame contains visible image data.
5. Capture a photo and wait for the capture callback.

## Results

- **0.5× CAMERA WORKING**
- **0.5× CAMERA NOT WORKING**

The project intentionally avoids health scores, trend analysis, and hardware speculation.

## Required privacy setting

Add the following camera usage description to the app target:

`NSCameraUsageDescription` — `This app needs camera access to test whether the 0.5× Ultra-Wide camera is functioning.`

## Important

A physical iPhone with an Ultra-Wide camera is required for a meaningful hardware test. The iOS Simulator cannot test the actual 0.5× camera hardware.
