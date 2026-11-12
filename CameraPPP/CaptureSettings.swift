//
//  CaptureSettings.swift
//  CameraPPP
//
//  錄影／拍照的解析度、拍照模式、儲存位置與人形偵測設定
//

@preconcurrency import AVFoundation
import Foundation

/// 錄影與拍照解析度（會同時影響錄影畫質、照片大小與耗電）
nonisolated enum CaptureResolution: String, CaseIterable, Identifiable {
    case hd720
    case hd1080
    case uhd4K

    static let storageKey = "captureResolution"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hd720: return "720p（最省電）"
        case .hd1080: return "1080p（清晰）"
        case .uhd4K: return "4K（最清晰，較耗電、佔空間）"
        }
    }

    var preset: AVCaptureSession.Preset {
        switch self {
        case .hd720: return .hd1280x720
        case .hd1080: return .hd1920x1080
        case .uhd4K: return .hd4K3840x2160
        }
    }

    static var current: CaptureResolution {
        CaptureResolution(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .hd720
    }
}

/// 拍照模式：畫質優先或速度優先
nonisolated enum PhotoCaptureMode: String, CaseIterable, Identifiable {
    case quality
    case balanced
    case speed

    static let storageKey = "photoCaptureMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quality: return "畫質優先"
        case .balanced: return "平衡"
        case .speed: return "速度優先"
        }
    }

    var subtitle: String {
        switch self {
        case .quality: return "照片最清楚，連拍時稍慢"
        case .balanced: return "畫質與速度兼顧"
        case .speed: return "拍照最快，適合快速連拍投影片"
        }
    }

    var prioritization: AVCapturePhotoOutput.QualityPrioritization {
        switch self {
        case .quality: return .quality
        case .balanced: return .balanced
        case .speed: return .speed
        }
    }

    static var current: PhotoCaptureMode {
        PhotoCaptureMode(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .quality
    }
}

nonisolated enum MediaPreferences {
    /// 錄完／拍完後是否同時存一份到「照片」App
    static let saveToPhotosKey = "saveToPhotosLibrary"

    /// 預設開啟：錄完的影片直接出現在 iPhone 的「照片」App（跟 1.3 版一樣）
    static var saveToPhotosLibrary: Bool {
        UserDefaults.standard.object(forKey: saveToPhotosKey) as? Bool ?? true
    }
}
