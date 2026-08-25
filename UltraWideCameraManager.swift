import Foundation
import AVFoundation
import SwiftUI

final class UltraWideCameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    @Published var sessionRunning = false
    @Published var cameraDetected = false
    @Published var frameReceived = false
    @Published var imageVisible = false
    @Published var photoCaptured = false
    @Published var photoCaptureFinished = false
    @Published var errorMessage: String?

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private var visibleFrameCount = 0
    private var totalFrameCount = 0

    func reset() {
        visibleFrameCount = 0
        totalFrameCount = 0
        DispatchQueue.main.async {
            self.cameraDetected = false
            self.frameReceived = false
            self.imageVisible = false
            self.photoCaptured = false
            self.photoCaptureFinished = false
            self.errorMessage = nil
        }
    }

    func setupCamera() {
        sessionQueue.async {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInUltraWideCamera],
                mediaType: .video,
                position: .back
            )

            guard let device = discovery.devices.first else {
                DispatchQueue.main.async {
                    self.errorMessage = "0.5× Ultra-Wide camera was not detected."
                }
                return
            }

            DispatchQueue.main.async { self.cameraDetected = true }

            if !self.configured {
                self.configure(device: device)
            }
            guard self.configured else { return }

            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async { self.sessionRunning = true }
            }
        }
    }

    private func configure(device: AVCaptureDevice) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CameraError.inputFailed }
            session.addInput(input)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(videoOutput) else { throw CameraError.videoOutputFailed }
            session.addOutput(videoOutput)

            guard session.canAddOutput(photoOutput) else { throw CameraError.photoOutputFailed }
            session.addOutput(photoOutput)
            configured = true
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Camera setup failed: \(error.localizedDescription)"
            }
        }
    }

    func capturePhoto() {
        guard configured else {
            DispatchQueue.main.async { self.errorMessage = "Camera is not configured." }
            return
        }

        DispatchQueue.main.async {
            self.photoCaptured = false
            self.photoCaptureFinished = false
        }

        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let success = error == nil && photo.fileDataRepresentation() != nil
        DispatchQueue.main.async {
            self.photoCaptured = success
            self.photoCaptureFinished = true
            if !success {
                self.errorMessage = "The 0.5× camera could not capture a photo."
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let brightness = calculateBrightness(pixelBuffer)
        totalFrameCount += 1
        if brightness > 0.03 { visibleFrameCount += 1 }
        let visible = visibleFrameCount > 0

        DispatchQueue.main.async {
            self.frameReceived = true
            if self.totalFrameCount >= 3 {
                self.imageVisible = visible
            }
        }
    }

    private func calculateBrightness(_ pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0 }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)

        var total: Double = 0
        var count = 0

        for y in stride(from: 0, to: height, by: 50) {
            for x in stride(from: 0, to: width, by: 50) {
                let offset = y * bytesPerRow + x * 4
                total += (Double(pixels[offset]) + Double(pixels[offset + 1]) + Double(pixels[offset + 2])) / 3.0 / 255.0
                count += 1
            }
        }

        return count > 0 ? total / Double(count) : 0
    }

    func stopCamera() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { self.sessionRunning = false }
        }
    }

    enum CameraError: LocalizedError {
        case inputFailed
        case videoOutputFailed
        case photoOutputFailed

        var errorDescription: String? {
            switch self {
            case .inputFailed: return "Unable to add the Ultra-Wide camera."
            case .videoOutputFailed: return "Unable to receive camera frames."
            case .photoOutputFailed: return "Unable to configure photo capture."
            }
        }
    }
}
