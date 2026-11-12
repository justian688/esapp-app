//
//  VideoTrimmerView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/22.
//

import SwiftUI
import AVKit
import AVFoundation

struct VideoTrimmerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var videoURLs: [URL] = []
    @State private var selectedVideo: URL? = nil
    @State private var videoDuration: Double = 0
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    @State private var isExporting = false
    @State private var exportMessage = ""
    @State private var showAlert = false
    @State private var shouldDismissAfterAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("課程剪輯")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.leading, 10)
                
                Spacer()
                
                if selectedVideo != nil {
                    Button(action: {
                        Task { await trimAndSaveVideo() }
                    }) {
                        if isExporting {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .padding()
            .background(Color.black)
            
            Divider()
            
            if let videoURL = selectedVideo {
                trimmerInterface(for: videoURL)
            } else {
                videoSelectionInterface()
            }
        }
        .background(Color.black)
        .task {
            videoURLs = await StorageManager.shared.fetchAllMedia()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Trimmer"), message: Text(exportMessage), dismissButton: .default(Text("OK")) {
                if shouldDismissAfterAlert {
                    dismiss()
                }
            })
        }
    }
    
    // MARK: - 影片選擇介面
    @ViewBuilder
    private func videoSelectionInterface() -> some View {
        if videoURLs.isEmpty {
            VStack {
                Spacer()
                Image(systemName: "film")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.bottom, 10)
                Text("No videos available to trim")
                    .foregroundColor(.gray)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(videoURLs, id: \.self) { url in
                        Button(action: {
                            loadVideoDetails(url: url)
                        }) {
                            HStack {
                                Image(systemName: "video.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text("Tap to select")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.black)
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
    }
    
    // MARK: - 剪輯操作介面
    @ViewBuilder
    private func trimmerInterface(for url: URL) -> some View {
        VStack {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 250)
                .background(Color.black)
            
            VStack(spacing: 25) {
                Text("Set Trim Range")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Start Time:").foregroundColor(.white)
                        Spacer()
                        Text(formatTime(startTime))
                            .foregroundColor(.blue)
                    }
                    Slider(value: $startTime, in: 0...max(0, endTime - 1))
                        .tint(.blue)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("End Time:").foregroundColor(.white)
                        Spacer()
                        Text(formatTime(endTime))
                            .foregroundColor(.red)
                    }
                    Slider(value: $endTime, in: min(startTime + 1, videoDuration)...videoDuration)
                        .tint(.red)
                }
                
                Spacer()
                
                Button(action: {
                    selectedVideo = nil
                }) {
                    Text("Choose Another Video")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            .background(Color.black)
            
            Spacer()
        }
    }
    
    // MARK: - 輔助方法
    private func loadVideoDetails(url: URL) {
        let asset = AVAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                
                await MainActor.run {
                    self.videoDuration = seconds
                    self.startTime = 0
                    self.endTime = seconds
                    self.selectedVideo = url
                }
            } catch {
                print("Failed to load video duration: \(error)")
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - 核心剪輯與輸出邏輯 (AVAssetExportSession)
    private func trimAndSaveVideo() async {
        guard let sourceURL = selectedVideo else { return }
        
        await MainActor.run { isExporting = true }
        
        let asset = AVAsset(url: sourceURL)
        let tempFileName = UUID().uuidString + "_trimmed.mp4"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFileName)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            await showResult(
                message: AppLanguage.current.localized("Cannot create trimming session.", "無法建立剪輯 Session。"),
                shouldDismiss: false
            )
            return
        }
        
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        
        exportSession.timeRange = timeRange
        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            do {
                // 呼叫我們之前寫好的 StorageManager 存入沙盒
                let _ = try await StorageManager.shared.saveVideo(from: tempURL)
                await showResult(
                    message: AppLanguage.current.localized("Trimming succeeded! Saved to private album.", "剪輯成功！已存入私密相簿。"),
                    shouldDismiss: true
                )
            } catch {
                await showResult(
                    message: AppLanguage.current.localized("Save failed: \(error.localizedDescription)", "儲存失敗：\(error.localizedDescription)"),
                    shouldDismiss: false
                )
            }
        } else {
            let errorMsg = exportSession.error?.localizedDescription ?? AppLanguage.current.localized("Unknown error", "未知錯誤")
            await showResult(
                message: AppLanguage.current.localized("Trimming failed: \(errorMsg)", "剪輯失敗：\(errorMsg)"),
                shouldDismiss: false
            )
        }
    }
    
    private func showResult(message: String, shouldDismiss: Bool) async {
        await MainActor.run {
            self.exportMessage = message
            self.shouldDismissAfterAlert = shouldDismiss
            self.isExporting = false
            self.showAlert = true
        }
    }
}
