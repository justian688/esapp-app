//
//  CourseViews.swift
//  CameraPPP
//
//  首頁的「目前課程」卡片、選課與新增課程、課程相簿與單一課程頁
//

import SwiftUI
import AVKit

// MARK: - 首頁：目前課程卡片

struct CurrentCourseCard: View {
    @State private var store = CourseStore.shared
    @State private var notesStore = CourseNotesStore.shared
    @AppStorage(RecordingPreferences.segmentMinutesKey) private var segmentMinutes = RecordingPreferences.defaultSegmentMinutes
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("目前課程")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
            }
            .foregroundColor(Theme.chalkYellow)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentCourse?.name ?? "未選擇課程")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(Theme.chalkWhite)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button {
                    showPicker = true
                } label: {
                    Text(store.currentCourse == nil ? "選擇課程" : "換一堂")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.chalkWhite)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Theme.chalkboard)
                        .overlay(Capsule().stroke(Theme.chalkLine, lineWidth: 1))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                if let course = store.currentCourse {
                    CourseChip(text: "已錄 \(store.videoCount(courseId: course.id)) 段")
                    CourseChip(text: "筆記 \(notesStore.count(courseId: course.id)) 則")
                }
                CourseChip(text: segmentMinutes > 0 ? "每 \(RecordingPreferences.durationLabel(segmentMinutes)) 自動存檔" : "不分段")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.chalkboard)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.chalkLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showPicker) {
            CoursePickerSheet()
        }
    }

    private var subtitle: String {
        if let course = store.currentCourse {
            return course.detailLine.isEmpty ? "錄好的影片會放進這堂課" : course.detailLine
        }
        return "錄好的影片會放在「未分類」"
    }
}

struct CourseChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.chalkboardDeep)
            .overlay(Capsule().stroke(Theme.chalkLine, lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - 選課

struct CoursePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CourseStore.shared
    @State private var editingCourse: Course?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.currentCourseId = nil
                        dismiss()
                    } label: {
                        CoursePickRow(title: "不指定課程", subtitle: "影片放在「未分類」", selected: store.currentCourseId == nil)
                    }
                    ForEach(store.courses) { course in
                        Button {
                            store.currentCourseId = course.id
                            dismiss()
                        } label: {
                            CoursePickRow(title: course.name, subtitle: course.detailLine, selected: store.currentCourseId == course.id)
                        }
                        .swipeActions {
                            Button("編輯") { editingCourse = course }
                                .tint(.gray)
                        }
                    }
                }
                Section {
                    Button {
                        editingCourse = Course(name: "")
                    } label: {
                        Label("新增課程", systemImage: "plus.circle.fill")
                            .foregroundColor(Theme.chalkYellow)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("選擇課程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .sheet(item: $editingCourse) { course in
                CourseEditor(course: course) { saved in
                    store.currentCourseId = saved.id
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct CoursePickRow: View {
    let title: String
    let subtitle: String
    let selected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.chalkWhite)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundColor(Theme.chalkYellow)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - 新增／編輯課程

struct CourseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var course: Course
    var onSaved: (Course) -> Void = { _ in }
    @State private var confirmDelete = false

    private var isExisting: Bool {
        CourseStore.shared.courses.contains { $0.id == course.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("課程名稱，例如：經濟學", text: $course.name)
                    TextField("上課時間，例如：週四 09:10", text: $course.schedule)
                    TextField("教室，例如：B203", text: $course.room)
                }
                if isExisting {
                    Section {
                        Button("刪除這堂課", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("刪除課程不會刪掉影片和照片，它們會移到「未分類」。")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(isExisting ? "編輯課程" : "新增課程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        course.name = course.name.trimmingCharacters(in: .whitespaces)
                        CourseStore.shared.save(course)
                        onSaved(course)
                        dismiss()
                    }
                    .disabled(course.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("確定要刪除「\(course.name)」嗎？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("刪除", role: .destructive) {
                    CourseStore.shared.delete(course)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 課程相簿（依課程）

struct CourseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = CourseStore.shared
    @State private var editingCourse: Course?
    @State private var showAllMedia = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(Theme.chalkWhite)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("返回")
                Text("課程相簿")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Theme.chalkWhite)
                Spacer()
                Button {
                    showAllMedia = true
                } label: {
                    Text("依日期")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.chalkYellow)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 8)
            .padding(.trailing, 8)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.courses) { course in
                        NavigationLink {
                            CourseDetailView(courseId: course.id)
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            CourseLibraryRow(
                                title: course.name,
                                subtitle: course.detailLine,
                                count: store.videoCount(courseId: course.id),
                                last: store.lastRecordedAt(courseId: course.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        CourseDetailView(courseId: nil)
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        CourseLibraryRow(
                            title: "未分類",
                            subtitle: "沒有選課程時錄的影片",
                            count: store.videoCount(courseId: nil),
                            last: store.lastRecordedAt(courseId: nil)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        editingCourse = Course(name: "")
                    } label: {
                        Label("新增課程", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.chalkYellow)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4])).foregroundColor(Theme.chalkLine))
                    }
                }
                .padding(16)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $editingCourse) { course in
            CourseEditor(course: course)
        }
        .fullScreenCover(isPresented: $showAllMedia) {
            GalleryView()
        }
    }
}

private struct CourseLibraryRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let last: Date?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundColor(Theme.chalkYellow)
                .frame(width: 52, height: 52)
                .background(Theme.chalkboardDeep)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.chalkLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.chalkWhite)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(count) 段")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.chalkYellow)
                Text(CourseFormat.relative(last))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(Theme.chalkboard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.chalkLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }
}

// MARK: - 單一課程：錄影、板書照片、筆記

struct CourseDetailView: View {
    let courseId: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var store = CourseStore.shared
    @State private var notesStore = CourseNotesStore.shared
    @State private var videos: [URL] = []
    @State private var photos: [URL] = []
    @State private var playingVideo: URL?
    @State private var viewingPhoto: URL?
    @State private var editingNote: CourseNote?
    @State private var editingCourse: Course?

    private var course: Course? { store.course(id: courseId) }

    private let photoColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title3)
                        .foregroundColor(Theme.chalkWhite)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("返回")
                VStack(alignment: .leading, spacing: 2) {
                    Text(course?.name ?? "未分類")
                        .font(.title3.weight(.bold))
                        .foregroundColor(Theme.chalkWhite)
                    if let line = course?.detailLine, !line.isEmpty {
                        Text(line)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                if let course {
                    Button("編輯") { editingCourse = course }
                        .foregroundColor(Theme.chalkYellow)
                        .frame(minHeight: 44)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sectionTitle("課堂錄影")
                    if videos.isEmpty {
                        emptyText("這堂課還沒有錄影。")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(videos.enumerated()), id: \.element) { index, url in
                                Button {
                                    playingVideo = url
                                } label: {
                                    CourseVideoRow(url: url, index: videos.count - index, date: store.media[url.lastPathComponent]?.recordedAt)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { mediaMenu(for: url, kind: .video) }
                            }
                        }
                    }

                    sectionTitle("板書與投影片")
                    if photos.isEmpty {
                        emptyText("錄影時點一下畫面就能拍照，會放在這裡。")
                    } else {
                        LazyVGrid(columns: photoColumns, spacing: 6) {
                            ForEach(photos, id: \.self) { url in
                                Button {
                                    viewingPhoto = url
                                } label: {
                                    PhotoThumbnailItem(url: url, isGridView: true)
                                        .frame(height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .contextMenu { mediaMenu(for: url, kind: .photo) }
                            }
                        }
                    }

                    if let courseId {
                        HStack {
                            sectionTitle("課程筆記")
                            Spacer()
                            Button("＋ 新增筆記") {
                                editingNote = CourseNote(title: "", body: "", courseId: courseId)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.chalkYellow)
                        }
                        let notes = notesStore.notes(courseId: courseId)
                        if notes.isEmpty {
                            emptyText("還沒有這堂課的筆記。")
                        } else {
                            ForEach(notes) { note in
                                Button {
                                    editingNote = note
                                } label: {
                                    HStack(spacing: 0) {
                                        Rectangle().fill(Color.red.opacity(0.3)).frame(width: 3)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(note.title.isEmpty ? "未命名筆記" : note.title)
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(Theme.chalkWhite)
                                            if !note.body.isEmpty {
                                                Text(note.body)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.gray)
                                                    .lineLimit(3)
                                            }
                                        }
                                        .padding(12)
                                        Spacer()
                                    }
                                    .background(Theme.chalkboard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task { await reload() }
        .fullScreenCover(item: Binding(
            get: { playingVideo.map { IdentifiableURL(url: $0) } },
            set: { playingVideo = $0?.url }
        )) { item in
            FullScreenVideoPlayer(videoURL: item.url)
        }
        .fullScreenCover(item: Binding(
            get: { viewingPhoto.map { IdentifiableURL(url: $0) } },
            set: { viewingPhoto = $0?.url }
        )) { item in
            FullScreenPhotoViewer(photoURL: item.url)
        }
        .sheet(item: $editingNote) { note in
            CourseNoteEditor(note: note, store: notesStore)
        }
        .sheet(item: $editingCourse) { course in
            CourseEditor(course: course)
        }
    }

    @ViewBuilder
    private func mediaMenu(for url: URL, kind: MediaKind) -> some View {
        Menu("移到其他課程") {
            Button("未分類") { move(url, to: nil) }
            ForEach(store.courses) { course in
                Button(course.name) { move(url, to: course.id) }
            }
        }
        Button(role: .destructive) {
            try? FileManager.default.removeItem(at: url)
            store.forget(fileURL: url)
            Task { await reload() }
        } label: {
            Label(kind == .video ? "刪除影片" : "刪除照片", systemImage: "trash")
        }
    }

    private func move(_ url: URL, to newCourse: UUID?) {
        store.move(fileURL: url, to: newCourse)
        Task { await reload() }
    }

    private func reload() async {
        let allVideos = await StorageManager.shared.fetchAllMedia()
        let allPhotos = await StorageManager.shared.fetchAllPhotos()
        videos = store.filter(allVideos, courseId: courseId)
        photos = store.filter(allPhotos, courseId: courseId)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .tracking(2)
            .foregroundColor(Theme.chalkYellow)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.gray)
    }
}

private struct CourseVideoRow: View {
    let url: URL
    let index: Int
    let date: Date?

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnailItem(url: url, isGridView: true)
                .frame(width: 96, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text("第 \(index) 段")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.chalkWhite)
                Text(date.map { CourseFormat.headerDate.string(from: $0) + " " + Self.time.string(from: $0) } ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
