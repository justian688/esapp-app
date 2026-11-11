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
    
    private let recordingPrompt = "It is recommended to mute your device./n Tap: Take photo/n Double-tap: End/n Swipe left/right: Change background"
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
//                if cameraManager.isHumanDetected {
//                    Text("⚠️ Motion Detected")
//                        .font(.caption)
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 6)
//                        .background(Color.red.opacity(0.8))
//                        .cornerRadius(15)
//                        .padding(.top, 10)
//                }
                
                if cameraManager.isRecording {
                    if showRecordingPrompt {
                        Text(LocalizedStringKey(recordingPrompt))
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                            .padding(.top, 14)
                    }
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.8), lineWidth: 4)
                        .frame(width: 220, height: 220)
                    
                    Text(timeString(time: timeElapsed))
                        .font(.system(size: 56, weight: .light, design: .default))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: startRecordingIfNeeded) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 90, height: 90)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 65, height: 65)
                            .shadow(radius: 3)
                        
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
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
                try await Task.sleep(nanoseconds: 3_000_000_000)
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
    
    private let recordingPrompt = "It is recommended to mute your device./n Tap: Take photo/n Double-tap: End/n Swipe left/right: Change background"
    
    var body: some View {
        ZStack {
            selectedBackground.backgroundView
            
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                if selectedBackground == .black && showRecordingPrompt {
                    Text(LocalizedStringKey(recordingPrompt))
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }
                
                Spacer(minLength: 0)
            }
            
            if cameraManager.isHumanDetected {
                VStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("偵測到有人")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(14)
                    .padding(.top, 60)
                    Spacer()
                }
                .allowsHitTesting(false)
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
            showRecordingPromptForThreeSeconds()
        }
        .onDisappear {
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
                try await Task.sleep(nanoseconds: 3_000_000_000)
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
