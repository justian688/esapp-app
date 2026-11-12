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
            "Tap: take photo\nDouble-tap: end\nSwipe left/right: change background",
            "點擊：拍照\n雙擊：結束\n左右滑動：切換背景"
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
                    // 粉筆框線風格：透明底＋細黃框，左邊小紅點代表錄影
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color(red: 0.72, green: 0.26, blue: 0.24))
                            .frame(width: 18, height: 18)
                        Text("開始上課")
                            .font(.system(size: 30, weight: .semibold))
                            .tracking(4)
                    }
                    .foregroundColor(Color(red: 0.85, green: 0.81, blue: 0.71))
                    .padding(.horizontal, 48)
                    .frame(height: 96)
                    .overlay(Capsule().stroke(Theme.chalkYellow.opacity(0.8), lineWidth: 2))
                    .contentShape(Capsule())
                }
                .accessibilityHint("開始錄影")
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
            "Tap: take photo\nDouble-tap: end\nSwipe left/right: change background",
            "點擊：拍照\n雙擊：結束\n左右滑動：切換背景"
        )
    }
    
    var body: some View {
        ZStack {
            selectedBackground.backgroundView
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if selectedBackground == .black && showRecordingPrompt {
                    RecordingGestureGuide()
                        .padding(.horizontal, 24)
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
            // 先維持原本亮度讓提示看得清楚，提示消失後才把亮度降到最低
            showRecordingPromptForThreeSeconds()
        }
        .onChange(of: selectedBackground) { _, mode in
            if mode == .black && !showRecordingPrompt {
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
                    withAnimation { showRecordingPrompt = false }
                    if selectedBackground == .black {
                        ScreenController.dimForBlackScreen()
                    }
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


/// 錄影黑屏時的操作說明：彩色圖示＋文字，一看就懂
private struct RecordingGestureGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GuideRow(icon: "camera.fill", color: Color(red: 0.95, green: 0.75, blue: 0.25), badge: nil, title: "點一下", detail: "拍照（不中斷錄影）")
            GuideRow(icon: "stop.fill", color: Color(red: 0.90, green: 0.32, blue: 0.30), badge: "2", title: "點兩下", detail: "結束錄影")
            GuideRow(icon: "arrow.left.and.right", color: Color(red: 0.35, green: 0.65, blue: 0.95), badge: nil, title: "左右滑動", detail: "切換黑屏／鏡頭畫面")
        }
        .padding(18)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color(white: 0.16))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity)
    }
}

private struct GuideRow: View {
    let icon: String
    let color: Color
    let badge: String?
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.18))
                    .overlay(Circle().stroke(color.opacity(0.6), lineWidth: 1))
                    .clipShape(Circle())
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 16, height: 16)
                        .background(color)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.8))
            }
        }
    }
}
