//
//  GalleryView.swift
//  CameraPPP
//
//  Created by Otis Lin on 2026/5/21.
//

import SwiftUI
import AVKit
import AVFoundation

struct GalleryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0 // 0: 影片, 1: 照片
    @State private var videoURLs: [URL] = []
    @State private var photoURLs: [URL] = []
    
    @State private var isGridView = true
    @State private var selectedVideo: URL? = nil
    @State private var selectedPhoto: URL? = nil
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("課程相簿")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.leading, 10)
                
                Spacer()
                
                Button(action: {
                    withAnimation { isGridView.toggle() }
                }) {
                    Image(systemName: isGridView ? "square.grid.2x2.fill" : "list.bullet")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.black)
            
            GalleryTabs(selectedTab: $selectedTab)
            
            ScrollView {
                if selectedTab == 0 {
                    if videoURLs.isEmpty {
                        EmptyStateView(message: "No videos found")
                    } else {
                        LazyVGrid(columns: isGridView ? columns : [GridItem(.flexible())], spacing: 2) {
                                                   ForEach(videoURLs, id: \.self) { url in
                                                       VideoThumbnailItem(url: url, isGridView: isGridView)
                                                           .onTapGesture {
                                                               selectedVideo = url
                                                           }
                                                           .contextMenu {
                                                               Button(role: .destructive, action: {
                                                                   deleteVideo(url: url)
                                                               }) {
                                                                   Label("Delete Video", systemImage: "trash")
                                                               }
                                                           }
                                                   }
                        }
                        .padding(.top, 2)
                    }
                } else {
                    if photoURLs.isEmpty {
                        EmptyStateView(message: "No photos found")
                    } else {
                        LazyVGrid(columns: isGridView ? columns : [GridItem(.flexible())], spacing: 2) {
                            ForEach(photoURLs, id: \.self) { url in
                                PhotoThumbnailItem(url: url, isGridView: isGridView)
                                    .onTapGesture {
                                        selectedPhoto = url
                                    }
                                    .contextMenu {
                                        Button(role: .destructive, action: {
                                            deletePhoto(url: url)
                                        }) {
                                            Label("Delete Photo", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .background(Color(UIColor.systemGray6))
        }
        .background(Color.white)
        .task {
            videoURLs = await StorageManager.shared.fetchAllMedia()
            photoURLs = await StorageManager.shared.fetchAllPhotos()
        }
        .fullScreenCover(item: Binding(
            get: { selectedVideo.map { IdentifiableURL(url: $0) } },
            set: { selectedVideo = $0?.url }
        )) { identifiableURL in
            FullScreenVideoPlayer(videoURL: identifiableURL.url)
        }
        .fullScreenCover(item: Binding(
            get: { selectedPhoto.map { IdentifiableURL(url: $0) } },
            set: { selectedPhoto = $0?.url }
        )) { identifiableURL in
            FullScreenPhotoViewer(photoURL: identifiableURL.url)
        }
    }
    
    private func deleteVideo(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            withAnimation {
                videoURLs.removeAll { $0 == url }
            }
            print("影片已成功刪除")
        } catch {
            print("刪除影片失敗: \(error.localizedDescription)")
        }
    }

    private func deletePhoto(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            withAnimation {
                photoURLs.removeAll { $0 == url }
            }
            print("照片已成功刪除")
        } catch {
            print("刪除照片失敗: \(error.localizedDescription)")
        }
    }
}

// 用來包裝 URL 讓它符合 Identifiable (給 fullScreenCover 使用)
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - 仿 Android 的 Tab 切換列
struct GalleryTabs: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 影片 Tab
                Button(action: { withAnimation { selectedTab = 0 } }) {
                    Image(systemName: "video.fill")
                        .font(.title3)
                        .foregroundColor(selectedTab == 0 ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                
                // 照片 Tab
                Button(action: { withAnimation { selectedTab = 1 } }) {
                    Image(systemName: "photo.fill")
                        .font(.title3)
                        .foregroundColor(selectedTab == 1 ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            
            // 底部指示線
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geo.size.width / 2, height: 2)
                    .offset(x: selectedTab == 0 ? 0 : geo.size.width / 2)
                    .animation(.easeInOut, value: selectedTab)
            }
            .frame(height: 2)
            
            Divider()
        }
        .background(Color.black)
    }
}

// MARK: - 空狀態畫面
struct EmptyStateView: View {
    var message: LocalizedStringKey
    var body: some View {
        VStack {
            Spacer(minLength: 150)
            Image(systemName: "folder")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 10)
            Text(message)
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 影片縮圖產生器與顯示元件
struct VideoThumbnailItem: View {
    let url: URL
    let isGridView: Bool
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack {
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: isGridView ? 120 : 200, maxHeight: isGridView ? 120 : 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: isGridView ? 120 : 200, maxHeight: isGridView ? 120 : 200)
                    .overlay(ProgressView())
            }
            
            // 影片播放圖示 (放在中間)
            Image(systemName: "play.circle.fill")
                .font(.system(size: isGridView ? 30 : 50))
                .foregroundColor(.white.opacity(0.8))
                .shadow(radius: 2)
            
            // 顯示影片時長 (放在右下角)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("MP4")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                }
            }
        }
        .task {
            await generateThumbnail()
        }
    }
    
    // 使用 AVAssetImageGenerator 非同步產生影片縮圖
    private func generateThumbnail() async {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            let (cgImage, _) = try await imageGenerator.image(at: time)
            await MainActor.run {
                self.thumbnail = UIImage(cgImage: cgImage)
            }
        } catch {
            print("無法產生縮圖: \(error)")
        }
    }
}

struct PhotoThumbnailItem: View {
    let url: URL
    let isGridView: Bool
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: isGridView ? 120 : 200, maxHeight: isGridView ? 120 : 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: isGridView ? 120 : 200, maxHeight: isGridView ? 120 : 200)
                    .overlay(ProgressView())
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("PHOTO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                }
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let data = try? Data(contentsOf: url),
              let loadedImage = UIImage(data: data) else {
            return
        }

        await MainActor.run {
            image = loadedImage
        }
    }
}

// MARK: - 全螢幕影片播放器
struct FullScreenVideoPlayer: View {
    let videoURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onAppear {
                    player = AVPlayer(url: videoURL)
                    player?.play()
                }
                .onDisappear {
                    player?.pause()
                }
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}

struct FullScreenPhotoViewer: View {
    let photoURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var image: UIImage? = nil
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let data = try? Data(contentsOf: photoURL),
              let loadedImage = UIImage(data: data) else {
            return
        }

        await MainActor.run {
            image = loadedImage
        }
    }
}
