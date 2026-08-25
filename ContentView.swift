import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var camera = UltraWideCameraManager()
    @State private var testing = false
    @State private var result: CameraResult?
    @State private var statusText = "Ready to test"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("0.5× Camera Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("iPhone Ultra-Wide Camera")
                    .foregroundStyle(.secondary)

                ZStack {
                    if camera.sessionRunning {
                        CameraPreview(session: camera.session)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay {
                                Image(systemName: "camera")
                                    .font(.system(size: 60))
                            }
                    }
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Text(statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if testing {
                    ProgressView("Testing 0.5× camera...")
                } else {
                    Button {
                        Task { await testCamera() }
                    } label: {
                        Text("Test 0.5× Camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let error = camera.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .navigationDestination(item: $result) { result in
                CameraTestResultView(working: result.working)
            }
        }
        .task {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }
        }
    }

    private func testCamera() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            camera.errorMessage = "Camera permission is required."
            return
        }

        testing = true
        result = nil
        camera.reset()

        statusText = "Checking for the 0.5× camera..."
        camera.setupCamera()

        guard await waitForCameraDetection() else {
            finishTest(working: false)
            return
        }

        statusText = "Checking live 0.5× camera output..."
        guard await waitForUsableCameraFrame() else {
            finishTest(working: false)
            return
        }

        statusText = "Capturing test photo..."
        camera.capturePhoto()
        finishTest(working: await waitForPhotoResult())
    }

    private func waitForCameraDetection(timeout: Int = 5) async -> Bool {
        for _ in 0..<(timeout * 10) {
            if camera.cameraDetected { return true }
            if camera.errorMessage != nil { return false }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    private func waitForUsableCameraFrame(timeout: Int = 5) async -> Bool {
        for _ in 0..<(timeout * 10) {
            if camera.frameReceived && camera.imageVisible { return true }
            if camera.errorMessage != nil { return false }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    private func waitForPhotoResult(timeout: Int = 5) async -> Bool {
        for _ in 0..<(timeout * 10) {
            if camera.photoCaptureFinished { return camera.photoCaptured }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    private func finishTest(working: Bool) {
        camera.stopCamera()
        testing = false
        result = CameraResult(working: working)
        statusText = working ? "0.5× camera is working." : "0.5× camera is not working."
    }
}

struct CameraResult: Identifiable {
    let id = UUID()
    let working: Bool
}
