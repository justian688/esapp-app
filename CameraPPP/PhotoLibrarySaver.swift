//
//  PhotoLibrarySaver.swift
//  CameraPPP
//
//  把錄好的影片、拍好的照片另存一份到「照片」App
//

import Foundation
import Photos

nonisolated enum PhotoLibrarySaver {
    /// 先詢問「加入照片」權限（只要求新增，不會讀取使用者的照片）
    @discardableResult
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    static func saveVideo(at url: URL) async {
        await save { _ = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }
    }

    static func savePhoto(at url: URL) async {
        await save { _ = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url) }
    }

    private static func save(_ change: @escaping @Sendable () -> Void) async {
        guard await requestAccess() else {
            print("未允許加入照片，略過存到照片 App")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges(change)
        } catch {
            print("存到照片 App 失敗：\(error)")
        }
    }
}
