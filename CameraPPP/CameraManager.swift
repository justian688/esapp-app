//
//  CameraManager.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/21.
//

@preconcurrency import AVFoundation
import Combine
import SwiftUI

enum CameraFacing: Int, CaseIterable, Identifiable {
    case back = 0
    case front = 1
    
    static let storageKey = "preferredCameraFacing"
    
    var id: Int { rawValue }
    
    var displayName: LocalizedStringKey {
        switch self {
        case .back:
            return "Back camera"
        case .front:
            return "Front camera"
        }
    }

    var settingsDisplayName: String {
        switch self {
        case .back:
            return "後置鏡頭"
        case .front:
            return "前置鏡頭"
        }
    }
    
    var avCapturePosition: AVCaptureDevice.Position {
        switch self {
        case .back:
            return .back
        case .front:
            return .front
        }
    }
}

nonisolated enum RecordingPreferences {
    /// 錄影完（到達時長）後是否自動接著錄下一段
    static let repeatRecordingKey = "repeatRecordingEnabled"
    /// 每段錄影的時長（分鐘），0 代表不限時長
    static let segmentMinutesKey = "recordingSegmentMinutes"
    static let defaultSegmentMinutes = 5

    static var isRepeatRecordingEnabled: Bool {
        UserDefaults.standard.object(forKey: repeatRecordingKey) as? Bool ?? true
    }

    static var segmentMinutes: Int {
        UserDefaults.standard.object(forKey: segmentMinutesKey) as? Int ?? defaultSegmentMinutes
    }
}

@Observable
final class CameraManager: NSObject, Sendable {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let fileOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var activePhotoCaptureDelegate: PhotoCaptureDelegate?
    
    private let sessionQueue = DispatchQueue(label: "com.app.camera.sessionQueue")
    private let motionDetector = MotionDetector()
    private var cameraFacing: CameraFacing

    var isRecording = false
    var isHumanDetected = false
    /// 只在 sessionQueue 上讀寫：使用者主動結束錄影時為 true，用來區分「時長到了」和「手動結束」
    @ObservationIgnored private var userRequestedStop = false
    @ObservationIgnored private var humanDetectedResetTask: Task<Void, Never>?
    var isAuthorized = false
    
    init(initialCameraFacing: CameraFacing = .back) {
        self.cameraFacing = initialCameraFacing
        super.init()
        Task {
            await checkPermission()
            if isAuthorized {
                sessionQueue.async { self.configureSession() }
            } else {
                print("使用者拒絕了相機權限")
            }
        }
    }
    
    // MARK: - 權限檢查
     private func checkPermission() async {
         let status = AVCaptureDevice.authorizationStatus(for: .video)
         switch status {
         case .authorized:
             isAuthorized = true
         case .notDetermined:
             isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
         case .denied, .restricted:
             isAuthorized = false
         @unknown default:
             isAuthorized = false
         }
     }
     
    
    private func configureSession() {
        session.beginConfiguration()
        let preset = CaptureResolution.current.preset
        session.sessionPreset = session.canSetSessionPreset(preset) ? preset : .hd1280x720
        
        installCameraInput()
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.app.camera.videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        // 先加錄影輸出，確保錄影一定拿得到畫面；人形偵測的畫面分析只在開啟時才加入
        if session.canAddOutput(fileOutput) { session.addOutput(fileOutput) }
        if MediaPreferences.isHumanDetectionEnabled, session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        session.commitConfiguration()
        updateMaxPhotoDimensions()
        session.startRunning()
    }

    /// 套用「錄影與拍照解析度」設定（錄影中不會變更，下次開始錄影前生效）
    func applyCaptureResolution() {
        sessionQueue.async {
            guard !self.fileOutput.isRecording else { return }
            let preset = CaptureResolution.current.preset
            guard self.session.sessionPreset != preset, self.session.canSetSessionPreset(preset) else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = preset
            self.session.commitConfiguration()
            self.updateMaxPhotoDimensions()
        }
    }

    /// 開關人形偵測時加入或移除畫面分析輸出（關閉時完全不分析畫面，省電，也避免和錄影搶畫面）
    func applyHumanDetectionSetting() {
        sessionQueue.async {
            guard !self.fileOutput.isRecording else { return }
            let enabled = MediaPreferences.isHumanDetectionEnabled
            let attached = self.session.outputs.contains(self.videoOutput)
            guard enabled != attached else { return }
            self.session.beginConfiguration()
            if enabled {
                if self.session.canAddOutput(self.videoOutput) { self.session.addOutput(self.videoOutput) }
            } else {
                self.session.removeOutput(self.videoOutput)
            }
            self.session.commitConfiguration()
        }
    }

    /// 讓照片使用目前鏡頭格式支援的最大尺寸。必須在 sessionQueue 上呼叫。
    private func updateMaxPhotoDimensions() {
        guard let device = (session.inputs.first as? AVCaptureDeviceInput)?.device,
              let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
                  Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
              }) else { return }
        photoOutput.maxPhotoDimensions = largest
    }

    func updateCameraFacing(_ facing: CameraFacing) {
        guard cameraFacing != facing else { return }
        cameraFacing = facing
        
        sessionQueue.async {
            guard self.session.isRunning, !self.fileOutput.isRecording else { return }
            self.session.beginConfiguration()
            self.installCameraInput()
            self.session.commitConfiguration()
            self.updateMaxPhotoDimensions()
        }
    }

    private func installCameraInput() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraFacing.avCapturePosition) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        for input in session.inputs {
            session.removeInput(input)
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
    }

    func startRecording() {
        sessionQueue.async {
            self.userRequestedStop = false
            self.beginRecordingSegment()
        }
    }

    /// 從 Siri 捷徑、小工具開啟 App 時使用：等相機準備好再開始錄影（最多等約 6 秒）
    func startRecordingWhenReady(attempt: Int = 0) {
        sessionQueue.async {
            if self.session.isRunning {
                self.userRequestedStop = false
                self.beginRecordingSegment()
            } else if attempt < 20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.startRecordingWhenReady(attempt: attempt + 1)
                }
            }
        }
    }

    /// 開始錄一段影片。必須在 sessionQueue 上呼叫。
    /// 有設定時長時，錄到時長會自動結束這一段；若「重複錄影」開啟，會在 delegate 裡接著錄下一段。
    private func beginRecordingSegment() {
        guard !fileOutput.isRecording else { return }

        let minutes = RecordingPreferences.segmentMinutes
        fileOutput.maxRecordedDuration = minutes > 0
            ? CMTime(seconds: Double(minutes * 60), preferredTimescale: 600)
            : .invalid

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        fileOutput.startRecording(to: tempURL, recordingDelegate: self)
        Task { @MainActor in self.isRecording = true }
    }
    
    func stopRecording() {
        sessionQueue.async {
            self.userRequestedStop = true
            self.fileOutput.stopRecording()
            Task { @MainActor in self.isRecording = false }
        }
    }

    /// 一段錄影結束後決定要不要自動接著錄。必須在 sessionQueue 上呼叫。
    private func handleSegmentFinished(error: Error?) {
        guard !userRequestedStop else { return }

        let nsError = error as NSError?
        let reachedDurationLimit = nsError?.code == AVError.Code.maximumDurationReached.rawValue

        if reachedDurationLimit, RecordingPreferences.isRepeatRecordingEnabled, session.isRunning {
            beginRecordingSegment()
        } else {
            // 時長到了但沒開重複錄影，或錄影因其他原因中斷：讓畫面回到未錄影狀態
            Task { @MainActor in self.isRecording = false }
        }
    }

    func capturePhoto() {
        sessionQueue.async {
            guard self.fileOutput.isRecording else { return }
            guard self.activePhotoCaptureDelegate == nil else { return }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.photoQualityPrioritization = PhotoCaptureMode.current.prioritization
            settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions

            let delegate = PhotoCaptureDelegate(manager: self)

            self.activePhotoCaptureDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    fileprivate func handleCapturedPhoto(data: Data?, error: Error?) {
        sessionQueue.async {
            self.activePhotoCaptureDelegate = nil
        }

        if let error {
            print("Failed to capture photo: \(error)")
            return
        }

        guard let data else {
            print("Failed to generate photo data")
            return
        }

        Task {
            do {
                let savedURL = try await StorageManager.shared.savePhoto(from: data)
                print("Securely saved photo to sandbox: \(savedURL)")
                if MediaPreferences.saveToPhotosLibrary {
                    await PhotoLibrarySaver.savePhoto(at: savedURL)
                }
            } catch {
                print("Failed to save photo: \(error)")
            }
        }
    }
}

// MARK: - Video Data Delegate (Vision Trigger)
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 人形偵測預設關閉以省電；開啟時也只在錄影中、每秒分析一次
        guard MediaPreferences.isHumanDetectionEnabled, fileOutput.isRecording else { return }
        Task {
            let detected = await motionDetector.detectHuman(in: sampleBuffer)
            guard detected else { return }
            await MainActor.run { self.markHumanDetected() }
        }
    }

    /// 顯示「偵測到有人」約 3 秒
    @MainActor
    private func markHumanDetected() {
        isHumanDetected = true
        humanDetectedResetTask?.cancel()
        humanDetectedResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self.isHumanDetected = false
        }
    }
}

// MARK: - File Output Delegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        sessionQueue.async {
            self.handleSegmentFinished(error: error)
        }

        // 錄影真的失敗（不是正常結束或到達時長）時，不存一個壞掉的空影片
        if let nsError = error as NSError?,
           (nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) != true {
            print("錄影失敗：\(nsError)")
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }

        Task {
            do {
                let savedURL = try await StorageManager.shared.saveVideo(from: outputFileURL)
                print("Securely saved to sandbox: \(savedURL)")
                if MediaPreferences.saveToPhotosLibrary {
                    await PhotoLibrarySaver.saveVideo(at: savedURL)
                }
            } catch {
                print("Failed to save video: \(error)")
            }
        }
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private unowned let manager: CameraManager
    
    init(manager: CameraManager) {
        self.manager = manager
    }
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            manager.handleCapturedPhoto(data: data, error: error)
        }
    }
}
