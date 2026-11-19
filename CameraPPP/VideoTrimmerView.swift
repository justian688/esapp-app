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
        .alert(tr("課程剪輯"), isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button(tr("好")) {
                if engine.exportSucceeded { onExported() }
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
            Button {
                Task {
                    engine.player.pause()
                    let ok = await engine.export(source: sourceURL)
                    resultMessage = ok ? tr("已匯出新影片，原始影片也保留著。") : (engine.lastError ?? tr("匯出失敗，請再試一次。"))
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
            Text(engine.hasEdits ? trf("%lld 段", engine.segments.count) : tr("原始長度"))
                .font(.system(size: 12)).foregroundColor(.gray)
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
            tool("arrow.uturn.backward", tr("復原"), id: "trim_undo", disabled: !engine.canUndo) {
                engine.undo(); selectedId = nil
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
    private var trimOrigin: ClipSegment?
    private var timeObserver: Any?
    /// 縮圖每隔幾秒取一張（依影片長度，最多約 150 張）
    private var thumbStep: Double = 2

    var totalDuration: Double { segments.reduce(0) { $0 + $1.length } }
    var hasEdits: Bool { segments.count != 1 || (segments.first.map { $0.start > 0.05 || $0.end < sourceDuration - 0.05 } ?? false) }
    var canUndo: Bool { !history.isEmpty }

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
        // 相鄰片段的範圍不能重疊（原始影片同一段不會出現兩次）
        let lowerBound = i > 0 && segments[i - 1].end <= origin.start ? segments[i - 1].end : 0
        let upperBound = i < segments.count - 1 && segments[i + 1].start >= origin.end ? segments[i + 1].start : sourceDuration
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
        segments = last
        Task { await rebuild(keepTime: min(currentTime, totalDuration)) }
    }

    func reset() {
        pushHistory()
        segments = [ClipSegment(start: 0, end: sourceDuration)]
        Task { await rebuild(keepTime: currentTime) }
    }

    private func pushHistory() {
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

    // MARK: 匯出

    func export(source: URL) async -> Bool {
        isExporting = true
        defer { isExporting = false }
        exportSucceeded = false
        guard let comp = await makeComposition(),
              let session = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else {
            lastError = tr("無法建立剪輯工作。")
            return false
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        do {
            try await session.export(to: tempURL, as: .mp4)
            let saved = try await StorageManager.shared.saveVideo(from: tempURL)
            // 剪好的影片歸到原本那堂課
            CourseStore.shared.move(fileURL: saved, to: CourseStore.shared.courseId(for: source))
            if MediaPreferences.saveToPhotosLibrary { await PhotoLibrarySaver.saveVideo(at: saved) }
            exportSucceeded = true
            return true
        } catch {
            lastError = trf("匯出失敗：%@", error.localizedDescription)
            return false
        }
    }
}
