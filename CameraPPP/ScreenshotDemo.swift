//
//  ScreenshotDemo.swift
//  CameraPPP
//
//  只在模擬器編譯：用示範資料自動產生 App Store 截圖（正式版不會包含）
//

#if targetEnvironment(simulator)
import AVFoundation
import SwiftUI
import UIKit

enum ScreenshotDemo {
    /// 啟動參數 -uiScreenshot <畫面>，例如 home、guide、gallery、courseInfo、notes、menu
    static var screen: String? { UserDefaults.standard.string(forKey: "uiScreenshot") }

    private static let seededKey = "screenshotDemoSeeded"

    @MainActor
    static func seedIfNeeded() async {
        guard screen != nil, !UserDefaults.standard.bool(forKey: seededKey) else { return }
        UserDefaults.standard.set(true, forKey: seededKey)

        let store = CourseStore.shared
        store.addCategory("學校課程")
        store.addCategory("演講")
        let calculus = Course(name: "微積分", schedule: "週一 09:10", room: "B203", teacher: "陳老師", category: "學校課程")
        let english = Course(name: "英文會話", schedule: "週三 13:20", room: "語言教室 2", teacher: "Ms. Lee", category: "學校課程")
        let marketing = Course(name: "數位行銷講座", schedule: "週五 19:00", room: "國際會議廳", teacher: "王講師", category: "演講")
        let physics = Course(name: "普通物理", schedule: "週四 10:10", room: "理學院 301", teacher: "林教授", category: "學校課程")
        for course in [calculus, english, marketing, physics] { store.save(course) }
        store.currentCourseId = calculus.id

        let notesStore = CourseNotesStore.shared
        notesStore.save(CourseNote(title: "微積分：極限與連續", body: "期中考範圍到第 3 章，ε-δ 定義要會寫。下週交作業 P.86 第 1–10 題。", courseId: calculus.id))
        notesStore.save(CourseNote(title: "英文會話：自我介紹", body: "練習 1 分鐘自我介紹，下堂課分組上台。", courseId: english.id))
        notesStore.save(CourseNote(title: "數位行銷：廣告投放重點", body: "先定目標受眾，再決定預算；每週檢查轉換率。", courseId: marketing.id))

        let boards: [(Course, String, String)] = [
            (calculus, "lim x→0  sin x / x = 1", "微積分 第 3 章"),
            (calculus, "∫ x² dx = x³/3 + C", "微積分 第 4 章"),
            (english, "How are you today?", "英文會話"),
            (marketing, "目標受眾 → 預算 → 轉換", "數位行銷講座"),
            (physics, "F = m a", "普通物理"),
            (physics, "E = m c²", "普通物理"),
            (calculus, "d/dx (eˣ) = eˣ", "微積分 第 5 章"),
            (english, "Nice to meet you!", "英文會話"),
            (marketing, "CTR · CPC · ROAS", "數位行銷講座"),
        ]
        for (index, board) in boards.enumerated() {
            let image = renderBoard(formula: board.1, caption: board.2, seed: index)
            if index % 3 == 2, let data = image.jpegData(compressionQuality: 0.9),
               let url = try? await StorageManager.shared.savePhoto(from: data) {
                store.move(fileURL: url, to: board.0.id)
            } else if let temp = makeVideo(from: image),
                      let url = try? await StorageManager.shared.saveVideo(from: temp) {
                store.move(fileURL: url, to: board.0.id)
            }
        }
    }

    private static func renderBoard(formula: String, caption: String, seed: Int) -> UIImage {
        let size = CGSize(width: 720, height: 1280)
        let greens: [UIColor] = [
            UIColor(red: 0.13, green: 0.22, blue: 0.18, alpha: 1),
            UIColor(red: 0.16, green: 0.20, blue: 0.24, alpha: 1),
            UIColor(red: 0.20, green: 0.17, blue: 0.14, alpha: 1),
        ]
        return UIGraphicsImageRenderer(size: size).image { ctx in
            greens[seed % greens.count].setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 1, alpha: 0.05).setFill()
            ctx.fill(CGRect(x: 0, y: 980, width: size.width, height: 300))
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let formulaAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .semibold),
                .foregroundColor: UIColor(white: 0.92, alpha: 1),
                .paragraphStyle: style,
            ]
            let captionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .bold),
                .foregroundColor: UIColor(red: 0.85, green: 0.76, blue: 0.48, alpha: 1),
                .paragraphStyle: style,
            ]
            (formula as NSString).draw(in: CGRect(x: 30, y: 480, width: size.width - 60, height: 300), withAttributes: formulaAttrs)
            (caption as NSString).draw(in: CGRect(x: 30, y: 200, width: size.width - 60, height: 80), withAttributes: captionAttrs)
        }
    }

    /// 把一張圖做成 2 秒的 mp4，讓課程相簿看起來像真的錄影
    private static func makeVideo(from image: UIImage) -> URL? {
        guard let cgImage = image.cgImage else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let width = cgImage.width, height = cgImage.height
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, nil, &buffer)
        guard let pixelBuffer = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        for frame in 0..<3 {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
            adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 1))
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        return writer.status == .completed ? url : nil
    }
}
#endif
