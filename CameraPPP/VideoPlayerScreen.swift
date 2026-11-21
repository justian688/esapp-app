//
//  VideoPlayerScreen.swift
//  CameraPPP
//
//  全螢幕影片播放（仿「照片」類 App 的版面）
//  上：返回、拍攝日期時間、更多（⋯）
//  中：影片（點一下顯示／隱藏控制列）
//  下：播放／暫停、目前時間／總長、靜音、進度條
//  底：分享、編輯（剪輯）、新增至（存到照片）、刪除
//
//  不用系統內建控制列，避免系統的投放按鈕跟關閉鈕疊在一起。
//

import SwiftUI
import AVFoundation
import Combine

struct FullScreenVideoPlayer: View {
    let videoURL: URL
    /// 刪除後通知外面重新整理清單；不給就不顯示刪除鈕
    var onDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = VideoPlaybackModel()
    @State private var controlsVisible = true
    @State private var showDeleteConfirm = false
    @State private var showTrimmer = false
    @State private var showInfo = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PlayerLayerView(player: model.player)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { controlsVisible.toggle() } }

            if controlsVisible {
                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    playbackBar
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    bottomToolbar
                }
                .transition(.opacity)
            }

            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: Capsule())
                    .transition(.opacity)
            }
        }
        .statusBarHidden(!controlsVisible)
        .onAppear { model.load(videoURL) }
        .onDisappear { model.pause() }
        .confirmationDialog(tr("刪除這部影片？"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(tr("刪除影片"), role: .destructive) { deleteVideo() }
            Button(tr("取消"), role: .cancel) {}
        } message: {
            Text(tr("刪除後無法復原。"))
        }
        .alert(tr("影片資訊"), isPresented: $showInfo) {
            Button(tr("好"), role: .cancel) {}
        } message: {
            Text(infoText)
        }
        .fullScreenCover(isPresented: $showTrimmer) {
            VideoTrimmerView(initialVideo: videoURL)
        }
        .onChange(of: showTrimmer) { _, open in
            if open { model.pause() } else { model.reload(videoURL) }   // 剪完若選了「取代」，重新載入剪好的版本
        }
    }

    // MARK: 上方列

    private var topBar: some View {
        HStack(alignment: .center) {
            circleButton("chevron.left", id: "player_back") { dismiss() }

            Spacer()

            VStack(spacing: 2) {
                Text(model.dateText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(model.timeText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Menu {
                Button { showInfo = true } label: { Label(tr("影片資訊"), systemImage: "info.circle") }
                Button { saveToPhotos() } label: { Label(tr("存到「照片」App"), systemImage: "photo.on.rectangle") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityIdentifier("player_more")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .top))
    }

    // MARK: 播放控制（影片下方）

    private var playbackBar: some View {
        VStack(spacing: 10) {
            HStack {
                circleButton(model.isPlaying ? "pause.fill" : "play.fill", id: "player_playPause") {
                    model.togglePlay()
                }
                Spacer()
                Text("\(Self.format(model.currentTime)) / \(Self.format(model.duration))")
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .accessibilityIdentifier("player_time")
                Spacer()
                circleButton(model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", id: "player_mute") {
                    model.isMuted.toggle()
                }
            }
            ScrubBar(progress: model.progress) { p, editing in
                model.scrub(to: p, finished: !editing)
            }
            .frame(height: 28)
            .accessibilityIdentifier("player_scrubber")
        }
    }

    // MARK: 底部工具列

    private var bottomToolbar: some View {
        HStack {
            toolButton("square.and.arrow.up", tr("分享"), id: "player_share") { share() }
            toolButton("slider.horizontal.3", tr("編輯"), id: "player_edit") { showTrimmer = true }
            Menu {
                Button { saveToPhotos() } label: { Label(tr("存到「照片」App"), systemImage: "photo.on.rectangle") }
            } label: {
                toolLabel("plus", tr("新增至"))
            }
            .accessibilityIdentifier("player_addTo")
            .frame(maxWidth: .infinity)
            if onDeleted != nil {
                toolButton("trash", tr("刪除"), id: "player_delete") { showDeleteConfirm = true }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Color.black.ignoresSafeArea(edges: .bottom))
    }

    // MARK: 小元件

    private func circleButton(_ icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.55), in: Circle())
        }
        .accessibilityIdentifier(id)
    }

    private func toolLabel(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 22))
            Text(title).font(.system(size: 13))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }

    private func toolButton(_ icon: String, _ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolLabel(icon, title) }
            .accessibilityIdentifier(id)
            .frame(maxWidth: .infinity)
    }

    // MARK: 動作

    private func share() {
        model.pause()
        guard let top = AdsManager.topViewController() else { return }
        let vc = UIActivityViewController(activityItems: [videoURL], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 1, height: 1)
        top.present(vc, animated: true)
    }

    private func saveToPhotos() {
        Task {
            let ok = await PhotoLibrarySaver.requestAccess()
            if ok { await PhotoLibrarySaver.saveVideo(at: videoURL) }
            showToast(ok ? tr("已存到照片") : tr("沒有權限存到照片，請到「設定」開啟"))
        }
    }

    private func deleteVideo() {
        model.pause()
        try? FileManager.default.removeItem(at: videoURL)
        CourseStore.shared.forget(fileURL: videoURL)
        onDeleted?()
        dismiss()
    }

    private func showToast(_ s: String) {
        withAnimation { toast = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } }
    }

    private var infoText: String {
        var lines = ["\(tr("時長"))：\(Self.format(model.duration))"]
        if let size = model.fileSize { lines.append("\(tr("檔案大小"))：\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))") }
        if let r = model.resolution { lines.append("\(tr("解析度"))：\(Int(r.width))×\(Int(r.height))") }
        lines.append(videoURL.lastPathComponent)
        return lines.joined(separator: "\n")
    }

    static func format(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "00:00" }
        let s = Int(t.rounded(.down))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - 播放狀態

@MainActor
final class VideoPlaybackModel: ObservableObject {
    let player = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isMuted = false { didSet { player.isMuted = isMuted } }
    @Published var dateText = ""
    @Published var timeText = ""
    @Published var fileSize: Int64?
    @Published var resolution: CGSize?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var isScrubbing = false

    var progress: Double { duration > 0 ? min(max(currentTime / duration, 0), 1) : 0 }

    func load(_ url: URL) {
        // 再次出現（例如從剪輯畫面回來）時不重複載入
        if player.currentItem != nil { return }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.isMuted = isMuted

        let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
        let date = values?.creationDate ?? Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: Translations.isEnglish ? "en_US" : "zh_Hant_TW")
        df.setLocalizedDateFormatFromTemplate("yMMMd")
        dateText = df.string(from: date)
        df.setLocalizedDateFormatFromTemplate("jmm")
        timeText = df.string(from: date)
        fileSize = values?.fileSize.map(Int64.init)

        Task {
            let asset = AVURLAsset(url: url)
            if let d = try? await asset.load(.duration) { duration = CMTimeGetSeconds(d) }
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let size = try? await track.load(.naturalSize),
               let t = try? await track.load(.preferredTransform) {
                let r = size.applying(t)
                resolution = CGSize(width: abs(r.width), height: abs(r.height))
            }
        }

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self, !self.isScrubbing else { return }
                self.currentTime = CMTimeGetSeconds(t)
                self.isPlaying = self.player.rate > 0
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isPlaying = false
                self?.currentTime = self?.duration ?? 0
            }
        }
        player.play()
        isPlaying = true
    }

    /// 檔案被替換（剪輯後取代原影片）時重新載入
    func reload(_ url: URL) {
        if let timeObserver { player.removeTimeObserver(timeObserver); self.timeObserver = nil }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver); self.endObserver = nil }
        player.replaceCurrentItem(with: nil)
        currentTime = 0
        load(url)
        pause()
    }

    func togglePlay() {
        if isPlaying {
            pause()
        } else {
            // 播完了再按播放 → 從頭開始
            if duration > 0, currentTime >= duration - 0.3 { player.seek(to: .zero); currentTime = 0 }
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func scrub(to p: Double, finished: Bool) {
        isScrubbing = !finished
        currentTime = p * duration
        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

// MARK: - 進度條（可拖曳、可點）

private struct ScrubBar: View {
    let progress: Double
    let onChange: (Double, Bool) -> Void
    @State private var dragging: Double?

    var body: some View {
        GeometryReader { geo in
            let p = dragging ?? progress
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35)).frame(height: 6)
                Capsule().fill(.white).frame(width: max(6, w * p), height: 6)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white)
                    .frame(width: 4, height: 26)
                    .offset(x: min(max(w * p - 2, 0), w - 4))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let x = min(max(v.location.x / w, 0), 1)
                        dragging = x
                        onChange(x, true)
                    }
                    .onEnded { v in
                        let x = min(max(v.location.x / w, 0), 1)
                        dragging = nil
                        onChange(x, false)
                    }
            )
        }
    }
}

// MARK: - AVPlayerLayer

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
