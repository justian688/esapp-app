//
//  RecordView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//

import SwiftUI
import UIKit

struct RecordView: View {
    var cameraManager: CameraManager
    
    @State private var timeElapsed = 0
    @State private var timer: Timer? = nil
    @State private var showRecordingPrompt = false
    @State private var recordingPromptTask: Task<Void, Never>? = nil
    
    private var recordingPrompt: String {
        AppLanguage.current.localized(
            "It is recommended to mute your device.\nTap: take photo\nDouble-tap: end\nSwipe left/right: change background",
            "建議將裝置轉為靜音。\n點擊：拍照\n雙擊：結束\n左右滑動：切換背景"
        )
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(CourseFormat.headerDate.string(from: Date()))
                        .font(.system(size: 13))
                        .tracking(1)
                        .foregroundColor(.gray)
                    CurrentCourseCard()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Theme.chalkboard, lineWidth: 14)
                        .frame(width: 210, height: 210)
                    Circle()
                        .stroke(Theme.chalkWhite.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [10, 6]))
                        .frame(width: 194, height: 194)
                    
                    Text(timeString(time: timeElapsed))
                        .font(.system(size: 56, weight: .light, design: .default))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: startRecordingIfNeeded) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.56, green: 0.12, blue: 0.10).opacity(0.25))
                            .frame(width: 86, height: 86)
                        Circle()
                            .fill(Color(red: 0.56, green: 0.12, blue: 0.10))
                            .frame(width: 64, height: 64)
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.95, green: 0.91, blue: 0.90))
                    }
                }
                .accessibilityLabel(CourseStore.shared.currentCourse == nil ? "開始錄影" : "開始錄這堂課")
                .disabled(cameraManager.isRecording)
                .opacity(cameraManager.isRecording ? 0.45 : 1.0)
                .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onChange(of: cameraManager.isRecording) { _, isRecording in
            if isRecording {
                startTimer()
                showRecordingPromptForThreeSeconds()
            } else {
                stopTimer()
                hideRecordingPrompt()
            }
        }
        .onDisappear {
            stopTimer()
            hideRecordingPrompt()
        }
    }

    private func startRecordingIfNeeded() {
        guard !cameraManager.isRecording else { return }
        cameraManager.startRecording()
    }
    
    private func startTimer() {
        timeElapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeElapsed += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timeElapsed = 0
    }

    private func showRecordingPromptForThreeSeconds() {
        recordingPromptTask?.cancel()
        showRecordingPrompt = true

        recordingPromptTask = Task {
            do {
                try await Task.sleep(nanoseconds: 6_000_000_000)
                try Task.checkCancellation()
                await MainActor.run {
                    showRecordingPrompt = false
                }
            } catch {
                // The task is cancelled when recording stops or the view disappears.
            }
        }
    }

    private func hideRecordingPrompt() {
        recordingPromptTask?.cancel()
        recordingPromptTask = nil
        showRecordingPrompt = false
    }
    
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RecordingOverlayView: View {
    var cameraManager: CameraManager
    
    @State private var selectedBackground: RecordingDisplayMode = .black
    @State private var showRecordingPrompt = false
    @State private var recordingPromptTask: Task<Void, Never>? = nil
    
    private var recordingPrompt: String {
        AppLanguage.current.localized(
            "It is recommended to mute your device.\nTap: take photo\nDouble-tap: end\nSwipe left/right: change background",
            "建議將裝置轉為靜音。\n點擊：拍照\n雙擊：結束\n左右滑動：切換背景"
        )
    }
    
    var body: some View {
        ZStack {
            selectedBackground.backgroundView
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if selectedBackground == .black && showRecordingPrompt {
                    RecordingGestureGuide()
                        .padding(.horizontal, 32)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            

            RecordingGestureOverlay(
                onSingleTap: capturePhoto,
                onDoubleTap: stopRecording,
                onSwipeLeft: showNextBackground,
                onSwipeRight: showPreviousBackground
            )
        }
        .onAppear {
            selectedBackground = .black
            ScreenController.dimForBlackScreen()
            showRecordingPromptForThreeSeconds()
        }
        .onChange(of: selectedBackground) { _, mode in
            if mode == .black {
                ScreenController.dimForBlackScreen()
            } else {
                ScreenController.restoreBrightness()
            }
        }
        .onDisappear {
            ScreenController.restoreBrightness()
            hideRecordingPrompt()
        }
    }
    
    private func capturePhoto() {
        guard cameraManager.isRecording else { return }
        cameraManager.capturePhoto()
    }
    
    private func stopRecording() {
        guard cameraManager.isRecording else { return }
        cameraManager.stopRecording()
    }
    
    private func showNextBackground() {
        guard cameraManager.isRecording else { return }
        selectedBackground = selectedBackground.next()
    }
    
    private func showPreviousBackground() {
        guard cameraManager.isRecording else { return }
        selectedBackground = selectedBackground.previous()
    }

    private func showRecordingPromptForThreeSeconds() {
        recordingPromptTask?.cancel()
        showRecordingPrompt = true

        recordingPromptTask = Task {
            do {
                try await Task.sleep(nanoseconds: 6_000_000_000)
                try Task.checkCancellation()
                await MainActor.run {
                    showRecordingPrompt = false
                }
            } catch {
                // The task is cancelled when the overlay disappears.
            }
        }
    }

    private func hideRecordingPrompt() {
        recordingPromptTask?.cancel()
        recordingPromptTask = nil
        showRecordingPrompt = false
    }
}

private enum RecordingDisplayMode: CaseIterable, Equatable {
    case black
    case preview
    
    var backgroundView: some View {
        Group {
            switch self {
            case .black:
                Color.black
            case .preview:
                Color.clear
            }
        }
        .ignoresSafeArea()
    }
    
    func next() -> RecordingDisplayMode {
        switch self {
        case .black:
            return .preview
        case .preview:
            return .black
        }
    }
    
    func previous() -> RecordingDisplayMode {
        switch self {
        case .black:
            return .preview
        case .preview:
            return .black
        }
    }
}

private struct RecordingGestureOverlay: UIViewRepresentable {
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    
    func makeUIView(context: Context) -> GestureCaptureView {
        let view = GestureCaptureView()
        view.onSingleTap = onSingleTap
        view.onDoubleTap = onDoubleTap
        view.onSwipeLeft = onSwipeLeft
        view.onSwipeRight = onSwipeRight
        return view
    }
    
    func updateUIView(_ uiView: GestureCaptureView, context: Context) {
        uiView.onSingleTap = onSingleTap
        uiView.onDoubleTap = onDoubleTap
        uiView.onSwipeLeft = onSwipeLeft
        uiView.onSwipeRight = onSwipeRight
    }
}

private final class GestureCaptureView: UIView {
    var onSingleTap: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    var onSwipeLeft: (() -> Void)?
    var onSwipeRight: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = true
        
        let doubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapRecognizer.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapRecognizer)
        
        let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        addGestureRecognizer(singleTapRecognizer)
        
        let leftSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        leftSwipeRecognizer.direction = .left
        addGestureRecognizer(leftSwipeRecognizer)
        
        let rightSwipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        rightSwipeRecognizer.direction = .right
        addGestureRecognizer(rightSwipeRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleSingleTap() {
        onSingleTap?()
    }
    
    @objc private func handleDoubleTap() {
        onDoubleTap?()
    }
    
    @objc private func handleSwipeLeft() {
        onSwipeLeft?()
    }
    
    @objc private func handleSwipeRight() {
        onSwipeRight?()
    }
}


/// 錄影黑屏時的操作說明：圖示＋文字，一看就懂
private struct RecordingGestureGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GuideRow(icon: "hand.tap.fill", badge: nil, title: "點一下", detail: "拍照（不中斷錄影）")
            GuideRow(icon: "hand.tap.fill", badge: "2", title: "點兩下", detail: "結束錄影")
            GuideRow(icon: "hand.draw.fill", badge: nil, title: "左右滑動", detail: "切換黑屏／鏡頭畫面")
            Divider().background(Color.white.opacity(0.15))
            HStack(spacing: 10) {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 15))
                    .frame(width: 44)
                Text("建議先將手機轉為靜音")
                    .font(.system(size: 14))
            }
            .foregroundColor(Color(white: 0.6))
        }
        .padding(22)
        .frame(maxWidth: 320, alignment: .leading)
        .background(Color(white: 0.08))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct GuideRow: View {
    let icon: String
    let badge: String?
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(Color(white: 0.85))
                    .frame(width: 44, height: 44)
                    .background(Color(white: 0.14))
                    .clipShape(Circle())
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 18, height: 18)
                        .background(Theme.chalkYellow)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(white: 0.9))
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.6))
            }
        }
    }
}
