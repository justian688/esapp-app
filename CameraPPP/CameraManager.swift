//
//  CameraManager.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/21.
//

@preconcurrency import AVFoundation
import UIKit
import Combine
import SwiftUI

enum CameraFacing: Int, CaseIterable, Identifiable {
    case back = 0
    case front = 1
    
    static let storageKey = "preferredCameraFacing"
    /// 預設前鏡頭（使用者沒選過時）
    static let defaultFacing: CameraFacing = .front

    static var saved: CameraFacing {
        (UserDefaults.standard.object(forKey: storageKey) as? Int).flatMap(CameraFacing.init(rawValue:)) ?? defaultFacing
    }
    
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
            return tr("後置鏡頭")
        case .front:
            return tr("前置鏡頭")
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
    static let defaultSegmentMinutes = 60
    /// 滑動選單可選的時長（分鐘），0 代表不限
    static let durationOptions = [3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 0]

    static func durationLabel(_ minutes: Int) -> String {
        if minutes == 0 { return tr("不限") }
        if minutes % 60 == 0 { return trf("%lld 小時", minutes / 60) }
        if minutes > 60 { return trf("%lld 小時 %lld 分鐘", minutes / 60, minutes % 60) }
        return trf("%lld 分鐘", minutes)
    }

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
    private let fileOutput = AVCaptureMovieFileOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var activePhotoCaptureDelegate: PhotoCaptureDelegate?
    
    private let sessionQueue = DispatchQueue(label: "com.app.camera.sessionQueue")
    private var cameraFacing: CameraFacing

    var isRecording = false
    /// 錄影無法開始或中途失敗時顯示給使用者看的原因
    var recordingErrorMessage: String?
    /// 錄影被來電、切到其他 App 等中斷（不是使用者自己結束）：回到 App 時詢問要不要繼續錄
    var interruptedRecording = false
    /// 只在 sessionQueue 上讀寫：使用者主動結束錄影時為 true，用來區分「時長到了」和「手動結束」
    @ObservationIgnored private var userRequestedStop = false
    /// 只在 sessionQueue 上讀寫：正在上課錄影、相機應該開著時為 true
    @ObservationIgnored private var wantsSessionRunning = false
    var isAuthorized = false
    /// 免費版錄滿 30 分鐘自動停止時為 true，畫面用來提示升級
    var freeLimitReached = false
    /// 免費版這次錄影會在何時自動停止（試用中／已訂閱為 nil），錄影畫面用來提前提醒
    var freeLimitEndsAt: Date?
    /// 只在 sessionQueue 上讀寫：這次錄影（含重複錄影的各段）開始的時間，用來算免費版 30 分鐘
    @ObservationIgnored private var sessionStartedAt: Date?
    /// 只在 sessionQueue 上讀寫：目前這段是不是被免費版 30 分鐘上限截斷
    @ObservationIgnored private var segmentCappedByFreeLimit = false
    
    init(initialCameraFacing: CameraFacing = .back) {
        self.cameraFacing = initialCameraFacing
        super.init()
        observeSessionInterruptions()
        // 打開 App 直接啟動相機（第一次會詢問相機與麥克風權限）
        requestPermissionsAndStart()
    }

    /// 詢問相機與麥克風權限並啟動相機（介紹頁按「開始使用」時呼叫）
    func requestPermissionsAndStart() {
        Task {
            await checkPermission()
            if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
            }
            if isAuthorized {
                sessionQueue.async {
                    // 只先設定好相機，不啟動；按下「開始上課」才打開相機（避免沒錄影時一直亮綠燈、耗電）
                    if self.session.inputs.isEmpty {
                        self.configureSession()
                    }
                }
            } else {
                print("使用者拒絕了相機權限")
            }
        }
    }

    // MARK: - 接電話、切換 App 等中斷後自動恢復相機
    private func observeSessionInterruptions() {
        let center = NotificationCenter.default
        let restart: @Sendable (Notification) -> Void = { [weak self] _ in
            self?.restartSessionIfNeeded()
        }
        center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil, using: restart)
        center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil, using: restart)
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil, using: restart)
    }

    func restartSessionIfNeeded() {
        sessionQueue.async {
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                  !self.session.inputs.isEmpty,
                  self.wantsSessionRunning,
                  !self.session.isRunning else { return }
            self.session.startRunning()
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
        session.sessionPreset = session.canSetSessionPreset(preset) ? preset
            : (session.canSetSessionPreset(.hd1920x1080) ? .hd1920x1080 : .hd1280x720)
        
        installCameraInput()
        installAudioInput()
        
        if session.canAddOutput(fileOutput) { session.addOutput(fileOutput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .quality
        
        session.commitConfiguration()
        updateMaxPhotoDimensions()
        applyFrameRate()
    }

    /// 沒在錄影時關掉相機，iPhone 上方的綠燈就會熄滅。必須在 sessionQueue 上呼叫。
    private func stopSessionIfIdle() {
        guard !fileOutput.isRecording else { return }
        wantsSessionRunning = false
        if session.isRunning { session.stopRunning() }
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
            self.applyFrameRate()
        }
    }

    /// 套用「錄影幀數」設定（錄影中不會變更，下次開始錄影前生效）
    func applyFrameRateSetting() {
        sessionQueue.async {
            guard !self.fileOutput.isRecording, !self.session.inputs.isEmpty else { return }
            self.applyFrameRate()
        }
    }

    /// 設定幀數：目前格式不支援時，找同解析度、支援該幀數的格式；
    /// 手機完全不支援（例如舊機沒有 4K 60fps）就用支援的最高幀數，不會出錯。必須在 sessionQueue 上呼叫。
    private func applyFrameRate() {
        guard let device = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first(where: { $0.hasMediaType(.video) }) else { return }
        let want = Double(CaptureFrameRate.current.rawValue)
        func maxRate(_ f: AVCaptureDevice.Format) -> Double {
            f.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
        }
        let current = device.activeFormat
        let dims = CMVideoFormatDescriptionGetDimensions(current.formatDescription)
        var format = current
        if maxRate(current) < want {
            let subtype = CMFormatDescriptionGetMediaSubType(current.formatDescription)
            let candidates = device.formats.filter {
                let d = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
                return d.width == dims.width && d.height == dims.height && maxRate($0) >= want
            }
            if let better = candidates.first(where: { CMFormatDescriptionGetMediaSubType($0.formatDescription) == subtype }) ?? candidates.first {
                format = better
            }
        }
        // 找一個「真的包含」目標幀數的範圍；設定值一定落在範圍內，避免 iOS 因不支援的幀數直接閃退
        let ranges = format.videoSupportedFrameRateRanges
        guard !ranges.isEmpty else { return }
        let target = min(want, maxRate(format))
        let range = ranges.first(where: { $0.minFrameRate <= target && target <= $0.maxFrameRate })
            ?? ranges.max(by: { $0.maxFrameRate < $1.maxFrameRate })!
        let fps = min(max(target, range.minFrameRate), range.maxFrameRate)
        var duration = CMTime(value: 1000, timescale: CMTimeScale((fps * 1000).rounded(.down)))
        // 夾在範圍允許的最短／最長時間之間
        if CMTimeCompare(duration, range.minFrameDuration) < 0 { duration = range.minFrameDuration }
        if CMTimeCompare(duration, range.maxFrameDuration) > 0 { duration = range.maxFrameDuration }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if format != current { device.activeFormat = format }
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            UserDefaults.standard.set(Int(fps.rounded()), forKey: CaptureFrameRate.actualKey)
        } catch {
            print("設定幀數失敗：\(error.localizedDescription)")
        }
    }

    /// 讓照片使用目前鏡頭格式支援的最大尺寸。必須在 sessionQueue 上呼叫。
    private func updateMaxPhotoDimensions() {
        guard let device = session.inputs.compactMap({ ($0 as? AVCaptureDeviceInput)?.device }).first(where: { $0.hasMediaType(.video) }),
              let largest = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
                  Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height)
              }) else { return }
        photoOutput.maxPhotoDimensions = largest
    }

    func updateCameraFacing(_ facing: CameraFacing) {
        guard cameraFacing != facing else { return }
        cameraFacing = facing
        
        sessionQueue.async {
            guard !self.session.inputs.isEmpty, !self.fileOutput.isRecording else { return }
            self.session.beginConfiguration()
            self.installCameraInput()
            self.session.commitConfiguration()
            self.updateMaxPhotoDimensions()
            self.applyFrameRate()
        }
    }

    private func installCameraInput() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraFacing.avCapturePosition) ??
                AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        for case let existing as AVCaptureDeviceInput in session.inputs where existing.device.hasMediaType(.video) {
            session.removeInput(existing)
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
    }

    /// 加入麥克風，讓錄影有聲音；使用者沒允許麥克風時就錄無聲影片
    private func installAudioInput() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
              !session.inputs.contains(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true }),
              let mic = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: mic),
              session.canAddInput(input) else { return }
        session.addInput(input)
    }

    func startRecording() {
        sessionQueue.async {
            self.userRequestedStop = false
            self.sessionStartedAt = nil
            self.beginRecordingSegment()
        }
    }

    /// 從 Siri 捷徑、小工具開啟 App 時使用：等相機準備好再開始錄影（最多等約 6 秒）
    /// resuming = 中斷後「繼續錄」：免費版的 30 分鐘接著算，不重新計時
    func startRecordingWhenReady(attempt: Int = 0, resuming: Bool = false) {
        sessionQueue.async {
            if !self.session.inputs.isEmpty {
                self.userRequestedStop = false
                if !resuming { self.sessionStartedAt = nil }
                self.beginRecordingSegment()
            } else if attempt < 20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.startRecordingWhenReady(attempt: attempt + 1, resuming: resuming)
                }
            }
        }
    }

    /// 中斷後使用者選「繼續錄」
    func resumeAfterInterruption() {
        interruptedRecording = false
        startRecordingWhenReady(resuming: true)
    }

    /// 開始錄一段影片。必須在 sessionQueue 上呼叫。
    /// 有設定時長時，錄到時長會自動結束這一段；若「重複錄影」開啟，會在 delegate 裡接著錄下一段。
    private func beginRecordingSegment() {
        guard !fileOutput.isRecording else { return }

        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            reportRecordingError(tr("沒有相機權限。請到「設定」→「es省電王」打開相機權限後再試一次。"))
            return
        }
        if session.inputs.isEmpty || session.outputs.isEmpty {
            configureSession()
        }
        wantsSessionRunning = true
        if !session.isRunning {
            session.startRunning()
        }
        guard session.isRunning, fileOutput.connection(with: .video) != nil else {
            stopSessionIfIdle()
            reportRecordingError(tr("相機還沒準備好，請稍等一下再按錄影。如果一直出現，請把 App 完全關掉再打開。"))
            return
        }

        let minutes = RecordingPreferences.segmentMinutes
        var maxSeconds: Double? = minutes > 0 ? Double(minutes * 60) : nil

        // 免費版：整次錄影（含重複錄影）最多 30 分鐘
        if sessionStartedAt == nil { sessionStartedAt = Date() }
        segmentCappedByFreeLimit = false
        if !FeatureAccess.hasFullAccess {
            let remaining = SubscriptionConfig.freeRecordingLimit - Date().timeIntervalSince(sessionStartedAt ?? Date())
            guard remaining > 1 else {
                stopSessionIfIdle()
                Task { @MainActor in
                    self.isRecording = false
                    self.freeLimitReached = true
                }
                return
            }
            if maxSeconds == nil || remaining < maxSeconds! {
                maxSeconds = remaining
                segmentCappedByFreeLimit = true
            }
            let endsAt = Date().addingTimeInterval(remaining)
            Task { @MainActor in self.freeLimitEndsAt = endsAt }
        } else {
            Task { @MainActor in self.freeLimitEndsAt = nil }
        }
        fileOutput.maxRecordedDuration = maxSeconds.map { CMTime(seconds: $0, preferredTimescale: 600) } ?? .invalid

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

    private func reportRecordingError(_ message: String) {
        print("錄影錯誤：\(message)")
        Task { @MainActor in
            self.isRecording = false
            self.recordingErrorMessage = message
        }
    }

    /// 一段錄影結束後決定要不要自動接著錄。必須在 sessionQueue 上呼叫。
    private func handleSegmentFinished(error: Error?) {
        guard !userRequestedStop else {
            stopSessionIfIdle()
            return
        }

        let nsError = error as NSError?
        let reachedDurationLimit = nsError?.code == AVError.Code.maximumDurationReached.rawValue

        if reachedDurationLimit, segmentCappedByFreeLimit {
            // 免費版錄滿 30 分鐘：停止並保存影片，停下後告訴使用者
            stopSessionIfIdle()
            Task { @MainActor in
                self.isRecording = false
                self.freeLimitReached = true
            }
        } else if reachedDurationLimit, RecordingPreferences.isRepeatRecordingEnabled, session.isRunning {
            beginRecordingSegment()
        } else {
            // 時長到了但沒開重複錄影，或錄影因其他原因中斷：讓畫面回到未錄影狀態，並關掉相機
            stopSessionIfIdle()
            let interrupted = nsError != nil && !reachedDurationLimit
            Task { @MainActor in
                self.isRecording = false
                // 來電、切到其他 App 等中斷：已錄的部分會自動保存，回到 App 時問要不要繼續錄
                if interrupted { self.interruptedRecording = true }
            }
        }
    }

    func capturePhoto() {
        sessionQueue.async {
            guard self.fileOutput.isRecording else { return }
            guard self.activePhotoCaptureDelegate == nil else { return }

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            // 不發出快門聲（iOS 18 起支援；日本、韓國等法規強制快門聲的地區系統會不允許）
            if self.photoOutput.isShutterSoundSuppressionSupported {
                settings.isShutterSoundSuppressionEnabled = true
            }
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
                await MainActor.run { CourseStore.shared.register(fileURL: savedURL, kind: .photo) }
                if MediaPreferences.saveToPhotosLibrary {
                    await PhotoLibrarySaver.savePhoto(at: savedURL)
                }
            } catch {
                print("Failed to save photo: \(error)")
            }
        }
    }
}


// MARK: - File Output Delegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    /// 檔案存在且有長度、可以讀出影片時間 → 可以保存
    nonisolated static func isPlayableVideo(_ url: URL) async -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        guard size > 0 else { return false }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return false }
        return duration.seconds.isFinite && duration.seconds > 0.5
    }

    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        sessionQueue.async {
            self.handleSegmentFinished(error: error)
        }

        let finishedCleanly = (error as NSError?).map { ($0.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) == true } ?? true

        Task {
            // 被中斷（來電、切 App、相機被搶走）時：已錄下的部分若還能播放就照樣保存，不整段遺失
            if !finishedCleanly {
                print("錄影中斷：\(String(describing: error))")
                guard await Self.isPlayableVideo(outputFileURL) else {
                    try? FileManager.default.removeItem(at: outputFileURL)
                    return
                }
            }
            do {
                let savedURL = try await StorageManager.shared.saveVideo(from: outputFileURL)
                print("Securely saved to sandbox: \(savedURL)")
                await MainActor.run { CourseStore.shared.register(fileURL: savedURL, kind: .video) }
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
