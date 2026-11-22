//
//  VideoTrimmerView.swift
//  CameraPPP
//
//  課程剪輯（參考剪映的操作方式）
//  ・上方預覽，看到的就是剪完的樣子（刪掉的片段會直接跳過）
//  ・下方縮圖時間軸，中間固定一條白色播放線；左右拖時間軸＝移動播放位置，雙指縮放
//  ・點一段片段 → 黃框選取，拖左右把手修剪頭尾
//  ・工具列：分割、刪除、復原、重設
//  ・匯出成新影片，歸到原本那堂課，原始影片保留
//

import SwiftUI
import AVFoundation
import Combine

struct VideoTrimmerView: View {
    /// 從播放畫面按「編輯」進來時，直接打開這部影片
    var initialVideo: URL? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var videoURLs: [URL] = []
    @State private var selectedVideo: URL? = nil

    init(initialVideo: URL? = nil) {
        self.initialVideo = initialVideo
    }

    var body: some View {
        Group {
            if let url = selectedVideo {
                ClipEditorView(sourceURL: url, onClose: {
                    if initialVideo != nil { dismiss() } else { selectedVideo = nil }
                }, onExported: { dismiss() })
            } else {
                videoPicker
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            if let initialVideo { selectedVideo = initialVideo; return }
            videoURLs = await StorageManager.shared.fetchAllMedia()
        }
    }

    // MARK: 選影片

    private var videoPicker: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                Text(tr("課程剪輯")).font(.title3.weight(.bold)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 8)

            if videoURLs.isEmpty {
                Spacer()
                Image(systemName: "film").font(.system(size: 50)).foregroundColor(.gray.opacity(0.5))
                Text(tr("還沒有影片可以剪輯")).foregroundColor(.gray).padding(.top, 8)
                Spacer()
            } else {
                Text(tr("選一部影片開始剪輯"))
                    .font(.subheadline).foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(videoURLs, id: \.self) { url in
                            Button { selectedVideo = url } label: {
                                TrimmerThumb(url: url)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct TrimmerThumb: View {
    let url: URL
    @State private var image: UIImage?
    @State private var duration: Double = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(white: 0.12)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            Text(FullScreenVideoPlayer.format(duration))
                .font(.caption2.monospacedDigit()).foregroundColor(.white)
                .padding(4)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .task {
            let asset = AVURLAsset(url: url)
            duration = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 240, height: 240)
            if let cg = try? await gen.image(at: .zero).image { image = UIImage(cgImage: cg) }
        }
    }
}

// MARK: - 片段

struct ClipSegment: Identifiable, Equatable {
    let id = UUID()
    /// 原始影片中的開始、結束秒數
    var start: Double
    var end: Double
    var length: Double { end - start }
}

// MARK: - 編輯器

private struct ClipEditorView: View {
    let sourceURL: URL
    let onClose: () -> Void
    let onExported: () -> Void

    @StateObject private var engine = ClipEngine()
    @State private var pxPerSec: CGFloat = 12
    @State private var pinchBase: CGFloat?
    @State private var dragBaseTime: Double?
    @State private var selectedId: UUID?
    @State private var confirmDiscard = false
    @State private var resultMessage: String?
    @State private var askReplace = false
    @State private var finished = false

    private let timelineHeight: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            topBar
            preview
            timeBar
            timeline
                .frame(height: timelineHeight + 36)
                .padding(.top, 6)
            toolbar
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            await engine.load(sourceURL)
            // 預設縮放：整部影片大約 3 個螢幕寬，太短的影片至少每秒 30 點
            let screen = UIScreen.main.bounds.width
            pxPerSec = min(80, max(0.5, screen * 3 / max(engine.sourceDuration, 1)))
        }
        .onDisappear { engine.player.pause() }
        .confirmationDialog(tr("放棄這次剪輯？"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(tr("放棄"), role: .destructive) { onClose() }
            Button(tr("繼續剪輯"), role: .cancel) {}
        }
        // 剪完詢問：取代原影片，還是另存一部新的
        .confirmationDialog(tr("剪好了，要怎麼儲存？"), isPresented: $askReplace, titleVisibility: .visible) {
            Button(tr("取代原影片"), role: .destructive) {
                Task {
                    let ok = await engine.commitReplacing(sourceURL)
                    finished = ok
                    resultMessage = ok ? tr("已取代原影片。") : (engine.lastError ?? tr("匯出失敗，請再試一次。"))
                }
            }
            Button(tr("另存新影片（保留原影片）")) {
                Task {
                    let ok = await engine.commitAsNew(from: sourceURL)
                    finished = ok
                    resultMessage = ok ? tr("已另存新影片，原始影片也保留著。") : (engine.lastError ?? tr("匯出失敗，請再試一次。"))
                }
            }
            Button(tr("取消"), role: .cancel) { engine.discardPendingExport() }
        } message: {
            Text(engine.exportedLossless ? tr("原畫質無損剪輯，畫質跟原片一樣。") : tr("這部影片的格式無法無損剪輯，已用最高畫質輸出。"))
        }
        .alert(tr("課程剪輯"), isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button(tr("好")) {
                if finished { onExported() }
            }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    // MARK: 上方列

    private var topBar: some View {
        HStack {
            Button {
                if engine.hasEdits { confirmDiscard = true } else { onClose() }
            } label: {
                Image(systemName: "xmark").font(.title3.weight(.semibold)).foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("trim_close")
            Spacer()
            Text(tr("課程剪輯")).font(.headline).foregroundColor(.white)
            Spacer()
            Text(tr("原畫質"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
            Button {
                Task {
                    engine.player.pause()
                    if await engine.export(source: sourceURL) {
                        askReplace = true
                    } else {
                        resultMessage = engine.lastError ?? tr("匯出失敗，請再試一次。")
                    }
                }
            } label: {
                Group {
                    if engine.isExporting {
                        ProgressView().tint(.black)
                    } else {
                        Text(tr("匯出")).font(.system(size: 15, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .frame(minWidth: 64, minHeight: 34)
                .background(Theme.chalkYellow, in: Capsule())
            }
            .disabled(engine.isExporting || engine.totalDuration < 0.5)
            .accessibilityIdentifier("trim_export")
        }
        .padding(.horizontal, 8)
    }

    // MARK: 預覽

    private var preview: some View {
        ZStack {
            Color.black
            PlayerLayerView(player: engine.player)
            if !engine.isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(.black.opacity(0.45), in: Circle())
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { engine.togglePlay() }
    }

    private var timeBar: some View {
        HStack {
            Text("\(FullScreenVideoPlayer.format(engine.currentTime)) / \(FullScreenVideoPlayer.format(engine.totalDuration))")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(.white)
            Spacer()
            Button { engine.togglePlay() } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18)).foregroundColor(.white)
                    .frame(width: 44, height: 36)
            }
            .accessibilityIdentifier("trim_play")
            Spacer()
            // 精簡：只留剪頭去尾、分割、刪除；復原／重做收起來（要重來按「重設」）
            Color.clear.frame(width: 100, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: 時間軸

    private var timeline: some View {
        GeometryReader { geo in
            let center = geo.size.width / 2
            let offsetX = center - CGFloat(engine.currentTime) * pxPerSec
            ZStack(alignment: .topLeading) {
                Color(white: 0.06)

                // 時間刻度
                timeRuler(width: geo.size.width, offsetX: offsetX)
                    .frame(height: 18)

                // 片段（縮圖條）
                HStack(spacing: 2) {
                    ForEach(engine.segments) { seg in
                        segmentView(seg)
                    }
                }
                .offset(x: offsetX, y: 24)

                // 中間固定的播放線
                Rectangle()
                    .fill(.white)
                    .frame(width: 2, height: timelineHeight + 16)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .offset(x: center - 1, y: 18)
                    .allowsHitTesting(false)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in
                        if dragBaseTime == nil { dragBaseTime = engine.currentTime; engine.player.pause() }
                        let t = (dragBaseTime ?? 0) - Double(v.translation.width / pxPerSec)
                        engine.seek(to: t)
                    }
                    .onEnded { _ in dragBaseTime = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if pinchBase == nil { pinchBase = pxPerSec }
                        pxPerSec = min(120, max(0.2, (pinchBase ?? pxPerSec) * v.magnification))
                    }
                    .onEnded { _ in pinchBase = nil }
            )
            .accessibilityIdentifier("trim_timeline")
        }
    }

    private func timeRuler(width: CGFloat, offsetX: CGFloat) -> some View {
        // 依縮放挑一個好讀的刻度間距（秒）
        let steps: [Double] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800]
        let step = steps.first { CGFloat($0) * pxPerSec >= 70 } ?? 3600
        let first = max(0, floor(Double(-offsetX / pxPerSec) / step) * step)
        let last = min(engine.totalDuration, Double((width - offsetX) / pxPerSec))
        let marks = stride(from: first, through: max(first, last), by: step).map { $0 }
        return ZStack(alignment: .topLeading) {
            ForEach(marks, id: \.self) { t in
                Text(FullScreenVideoPlayer.format(t))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.gray)
                    .offset(x: offsetX + CGFloat(t) * pxPerSec - 14, y: 2)
            }
        }
    }

    private func segmentView(_ seg: ClipSegment) -> some View {
        let w = max(4, CGFloat(seg.length) * pxPerSec)
        let selected = selectedId == seg.id
        return ZStack {
            FilmStrip(engine: engine, segment: seg, width: w, height: timelineHeight)
            if selected {
                RoundedRectangle(cornerRadius: 6).stroke(Theme.chalkYellow, lineWidth: 3)
                HStack {
                    trimHandle(seg, leading: true)
                    Spacer()
                    trimHandle(seg, leading: false)
                }
            }
        }
        .frame(width: w, height: timelineHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { selectedId = selected ? nil : seg.id } }
    }

    private func trimHandle(_ seg: ClipSegment, leading: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Theme.chalkYellow)
            .frame(width: 14)
            .overlay(Capsule().fill(.black.opacity(0.6)).frame(width: 3, height: 20))
            .contentShape(Rectangle().inset(by: -10))
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        engine.player.pause()
                        engine.trim(seg.id, leading: leading, by: Double(v.translation.width / pxPerSec), live: true)
                    }
                    .onEnded { v in
                        engine.trim(seg.id, leading: leading, by: Double(v.translation.width / pxPerSec), live: false)
                    }
            )
            .accessibilityIdentifier(leading ? "trim_handle_left" : "trim_handle_right")
    }

    // MARK: 工具列

    private var toolbar: some View {
        HStack {
            tool("scissors", tr("分割"), id: "trim_split") {
                engine.split(at: engine.currentTime)
            }
            tool("trash", tr("刪除"), id: "trim_delete", disabled: selectedId == nil || engine.segments.count <= 1) {
                if let id = selectedId { engine.delete(id); selectedId = nil }
            }
            tool("arrow.counterclockwise", tr("重設"), id: "trim_reset", disabled: !engine.hasEdits) {
                engine.reset(); selectedId = nil
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color.black)
        .overlay(alignment: .top) {
            Text(selectedId == nil ? tr("點一段片段可以選取、拖兩端修剪；左右拖時間軸移動、雙指縮放") : tr("拖黃色把手修剪頭尾，或按「刪除」移除這段"))
                .font(.system(size: 11)).foregroundColor(.gray)
                .offset(y: -14)
        }
    }

    private func tool(_ icon: String, _ title: String, id: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 21))
                Text(title).font(.system(size: 12))
            }
            .foregroundColor(disabled ? .gray.opacity(0.4) : .white)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .disabled(disabled)
        .accessibilityIdentifier(id)
    }
}

// MARK: - 縮圖條

private struct FilmStrip: View {
    @ObservedObject var engine: ClipEngine
    let segment: ClipSegment
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let tileW = height * 0.75
        let count = max(1, Int(ceil(width / tileW)))
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                let t = segment.start + segment.length * (Double(i) + 0.5) / Double(count)
                ZStack {
                    Color(white: 0.18)
                    if let img = engine.thumbnail(near: t) {
                        Image(uiImage: img).resizable().scaledToFill()
                    }
                }
                .frame(width: tileW, height: height)
                .clipped()
            }
        }
        .frame(width: width, height: height, alignment: .leading)
        .clipped()
    }
}

// MARK: - 剪輯引擎（片段、預覽、匯出）

@MainActor
final class ClipEngine: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var segments: [ClipSegment] = []
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isExporting = false
    @Published private(set) var thumbs: [Int: UIImage] = [:]
    @Published private(set) var exportSucceeded = false
    private(set) var sourceDuration: Double = 0
    private(set) var lastError: String?

    private var asset: AVURLAsset?
    private var history: [[ClipSegment]] = []
    private var future: [[ClipSegment]] = []
    private var trimOrigin: ClipSegment?
    private var timeObserver: Any?
    /// 縮圖每隔幾秒取一張（依影片長度，最多約 150 張）
    private var thumbStep: Double = 2

    var totalDuration: Double { segments.reduce(0) { $0 + $1.length } }
    var hasEdits: Bool { segments.count != 1 || (segments.first.map { $0.start > 0.05 || $0.end < sourceDuration - 0.05 } ?? false) }
    var canUndo: Bool { !history.isEmpty }
    var canRedo: Bool { !future.isEmpty }
    /// 匯出好、等使用者決定「取代／另存」的暫存檔
    private(set) var pendingExport: URL?
    /// 這次是否為無損（直接複製原始影像、不重新壓縮）
    private(set) var exportedLossless = false

    func load(_ url: URL) async {
        let asset = AVURLAsset(url: url)
        self.asset = asset
        sourceDuration = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
        segments = [ClipSegment(start: 0, end: sourceDuration)]
        thumbStep = max(1, sourceDuration / 150)
        await rebuild(keepTime: 0)

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] t in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isPlaying = self.player.rate > 0
                if self.isPlaying { self.currentTime = min(CMTimeGetSeconds(t), self.totalDuration) }
            }
        }
        await generateThumbnails()
    }

    // MARK: 播放

    func togglePlay() {
        if isPlaying {
            player.pause(); isPlaying = false
        } else {
            if currentTime >= totalDuration - 0.1 { seek(to: 0) }
            player.play(); isPlaying = true
        }
    }

    func seek(to t: Double) {
        currentTime = min(max(0, t), totalDuration)
        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: 編輯

    func split(at t: Double) {
        // 時間軸時間 → 哪一段、原始影片的第幾秒
        var acc = 0.0
        for (i, seg) in segments.enumerated() {
            if t > acc + 0.2 && t < acc + seg.length - 0.2 {
                let cut = seg.start + (t - acc)
                pushHistory()
                segments[i] = ClipSegment(start: seg.start, end: cut)
                segments.insert(ClipSegment(start: cut, end: seg.end), at: i + 1)
                return
            }
            acc += seg.length
        }
    }

    func delete(_ id: UUID) {
        guard segments.count > 1 else { return }
        pushHistory()
        segments.removeAll { $0.id == id }
        Task { await rebuild(keepTime: currentTime) }
    }

    /// 拖把手修剪：leading = 左把手（改開始），否則改結束；delta 是時間軸上移動的秒數
    func trim(_ id: UUID, leading: Bool, by delta: Double, live: Bool) {
        guard let i = segments.firstIndex(where: { $0.id == id }) else { return }
        if trimOrigin == nil { trimOrigin = segments[i]; pushHistory() }
        guard let origin = trimOrigin else { return }
        // 跟剪映一樣：可以往外拉回原影片的任何位置
        let lowerBound = 0.0
        let upperBound = sourceDuration
        var seg = segments[i]
        if leading {
            seg.start = min(max(lowerBound, origin.start + delta), origin.end - 0.5)
        } else {
            seg.end = max(min(upperBound, origin.end + delta), origin.start + 0.5)
        }
        segments[i] = seg
        if !live {
            trimOrigin = nil
            Task { await rebuild(keepTime: min(currentTime, totalDuration)) }
        }
    }

    func undo() {
        guard let last = history.popLast() else { return }
        future.append(segments)
        segments = last
        Task { await rebuild(keepTime: min(currentTime, totalDuration)) }
    }

    func redo() {
        guard let next = future.popLast() else { return }
        history.append(segments)
        segments = next
        Task { await rebuild(keepTime: min(currentTime, totalDuration)) }
    }

    /// 複製一段（放在它後面）
    func duplicate(_ id: UUID) {
        guard let i = segments.firstIndex(where: { $0.id == id }) else { return }
        pushHistory()
        let s = segments[i]
        segments.insert(ClipSegment(start: s.start, end: s.end), at: i + 1)
        Task { await rebuild(keepTime: currentTime) }
    }

    func reset() {
        pushHistory()
        segments = [ClipSegment(start: 0, end: sourceDuration)]
        Task { await rebuild(keepTime: currentTime) }
    }

    private func pushHistory() {
        future.removeAll()
        history.append(segments)
        if history.count > 30 { history.removeFirst() }
    }

    // MARK: 預覽用的合成影片

    private func makeComposition() async -> AVMutableComposition? {
        guard let asset else { return nil }
        let comp = AVMutableComposition()
        guard let srcVideo = try? await asset.loadTracks(withMediaType: .video).first,
              let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        let srcAudio = try? await asset.loadTracks(withMediaType: .audio).first
        let aTrack = srcAudio == nil ? nil : comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var cursor = CMTime.zero
        for seg in segments {
            let range = CMTimeRange(start: CMTime(seconds: seg.start, preferredTimescale: 600),
                                    end: CMTime(seconds: seg.end, preferredTimescale: 600))
            try? vTrack.insertTimeRange(range, of: srcVideo, at: cursor)
            if let srcAudio, let aTrack { try? aTrack.insertTimeRange(range, of: srcAudio, at: cursor) }
            cursor = cursor + range.duration
        }
        vTrack.preferredTransform = (try? await srcVideo.load(.preferredTransform)) ?? .identity
        return comp
    }

    private func rebuild(keepTime: Double) async {
        guard let comp = await makeComposition() else { return }
        let wasPlaying = isPlaying
        player.replaceCurrentItem(with: AVPlayerItem(asset: comp))
        seek(to: min(keepTime, totalDuration))
        if wasPlaying { player.play() }
    }

    // MARK: 縮圖

    func thumbnail(near t: Double) -> UIImage? {
        let key = Int((t / thumbStep).rounded())
        return thumbs[key] ?? thumbs[key - 1] ?? thumbs[key + 1]
    }

    private func generateThumbnails() async {
        guard let asset else { return }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 120, height: 120)
        gen.requestedTimeToleranceBefore = CMTime(seconds: thumbStep / 2, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: thumbStep / 2, preferredTimescale: 600)
        let times = stride(from: 0.0, to: max(sourceDuration, 0.1), by: thumbStep).map { CMTime(seconds: $0, preferredTimescale: 600) }
        for await result in gen.images(for: times) {
            if let cg = try? result.image {
                let key = Int((CMTimeGetSeconds(result.requestedTime) / thumbStep).rounded())
                thumbs[key] = UIImage(cgImage: cg)
            }
        }
    }

    // MARK: 匯出（無損優先）

    /// 匯出到暫存檔；成功後由畫面詢問「取代原影片」或「另存新影片」
    func export(source: URL) async -> Bool {
        isExporting = true
        defer { isExporting = false }
        exportSucceeded = false
        lastError = nil
        guard let comp = await makeComposition() else {
            lastError = tr("無法建立剪輯工作。")
            return false
        }
        let ext = source.pathExtension.isEmpty ? "mp4" : source.pathExtension
        let type: AVFileType = ext.lowercased() == "mov" ? .mov : .mp4
        // 1) 無損：直接複製原始影像資料，不重新壓縮（畫質跟原片一樣，速度快）
        for (preset, lossless) in [(AVAssetExportPresetPassthrough, true), (AVAssetExportPresetHighestQuality, false)] {
            guard let session = AVAssetExportSession(asset: comp, presetName: preset) else { continue }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
            do {
                try await session.export(to: tempURL, as: type)
                pendingExport = tempURL
                exportedLossless = lossless
                exportSucceeded = true
                return true
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                lastError = trf("匯出失敗：%@", error.localizedDescription)
                // 2) 無損失敗（少數格式不支援）→ 改用最高畫質重新壓縮
            }
        }
        return false
    }

    /// 使用者選「取代原影片」：檔名、所屬課程都不變
    func commitReplacing(_ source: URL) async -> Bool {
        guard let temp = pendingExport else { return false }
        do {
            _ = try FileManager.default.replaceItemAt(source, withItemAt: temp)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: source.path)
            pendingExport = nil
            if MediaPreferences.saveToPhotosLibrary { await PhotoLibrarySaver.saveVideo(at: source) }
            return true
        } catch {
            lastError = trf("匯出失敗：%@", error.localizedDescription)
            return false
        }
    }

    /// 使用者選「另存新影片」：原影片保留，新影片歸到同一堂課
    func commitAsNew(from source: URL) async -> Bool {
        guard let temp = pendingExport else { return false }
        do {
            let saved = try await StorageManager.shared.saveVideo(from: temp)
            CourseStore.shared.move(fileURL: saved, to: CourseStore.shared.courseId(for: source))
            pendingExport = nil
            if MediaPreferences.saveToPhotosLibrary { await PhotoLibrarySaver.saveVideo(at: saved) }
            return true
        } catch {
            lastError = trf("匯出失敗：%@", error.localizedDescription)
            return false
        }
    }

    func discardPendingExport() {
        if let temp = pendingExport { try? FileManager.default.removeItem(at: temp) }
        pendingExport = nil
    }
}
