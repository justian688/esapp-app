//
//  CourseNotes.swift
//  CameraPPP
//
//  課程筆記：記錄每堂課的重點，存在手機本機
//

import Foundation
import Observation
import SwiftUI

struct CourseNote: Identifiable, Codable, Equatable {
    static let defaultTitle = "一般筆記"

    var id = UUID()
    var title: String
    var body: String
    var updatedAt = Date()
    /// 這則筆記屬於哪一堂課（nil = 未指定）
    var courseId: UUID?
    /// 預設的「一般筆記」：永遠存在、排第一、不能刪除、標題不能改
    var isDefault = false

    init(id: UUID = UUID(), title: String, body: String, updatedAt: Date = Date(), courseId: UUID? = nil, isDefault: Bool = false) {
        self.id = id; self.title = title; self.body = body
        self.updatedAt = updatedAt; self.courseId = courseId; self.isDefault = isDefault
    }

    // 舊版存的筆記沒有 isDefault 欄位
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        courseId = try c.decodeIfPresent(UUID.self, forKey: .courseId)
        isDefault = try c.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
    }
}

@Observable
final class CourseNotesStore {
    static let shared = CourseNotesStore()

    private(set) var notes: [CourseNote] = []

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("course_notes.json")
    }()

    private init() {
        load()
        ensureDefaultNote()
    }

    func save(_ note: CourseNote) {
        var updated = note
        updated.updatedAt = Date()
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updated
        } else {
            notes.insert(updated, at: 0)
        }
        sortNotes()
        persist()
    }

    /// 一般筆記固定排第一，其他依更新時間
    private func sortNotes() {
        notes.sort { a, b in
            if a.isDefault != b.isDefault { return a.isDefault }
            return a.updatedAt > b.updatedAt
        }
    }

    /// 沒有「一般筆記」就建立一則（放在一般課程底下）
    private func ensureDefaultNote() {
        guard !notes.contains(where: { $0.isDefault }) else { return }
        let general = CourseStore.shared.courses.first { $0.name == Course.defaultCourseName }
        notes.insert(CourseNote(title: CourseNote.defaultTitle, body: "", courseId: general?.id, isDefault: true), at: 0)
        persist()
    }

    func notes(courseId: UUID) -> [CourseNote] {
        notes.filter { $0.courseId == courseId }
    }

    func count(courseId: UUID?) -> Int {
        notes.filter { $0.courseId == courseId }.count
    }

    func delete(_ note: CourseNote) {
        guard !note.isDefault else { return }   // 一般筆記不能刪除
        notes.removeAll { $0.id == note.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CourseNote].self, from: data) else { return }
        notes = decoded
        sortNotes()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("課程筆記儲存失敗：\(error)")
        }
    }
}

// MARK: - 排程頁中的「課程筆記」區塊

struct CourseNotesSection: View {
    @State private var store = CourseNotesStore.shared
    @State private var editingNote: CourseNote?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                ChalkSectionTitle(icon: "pencil.and.list.clipboard", title: "課程筆記")
                Spacer()
                Button {
                    editingNote = CourseNote(title: "", body: "", courseId: CourseStore.shared.currentCourseId)
                } label: {
                    Label("新增筆記", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.chalkYellow)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 10)

            if store.notes.isEmpty {
                Text("還沒有筆記。上課時按「新增筆記」，記下課程名稱和重點，課後搭配錄影一起複習。")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            } else {
                ForEach(store.notes) { note in
                    Button {
                        editingNote = note
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: note.isDefault ? "pin.fill" : "pencil.line")
                                .foregroundColor(note.isDefault ? Theme.chalkYellow : .white)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title.isEmpty ? tr("未命名課程") : (note.isDefault ? tr(note.title) : note.title))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if !note.body.isEmpty {
                                    Text(note.body)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                Text([CourseStore.shared.course(id: note.courseId).map { tr($0.name) }, Self.dateFormatter.string(from: note.updatedAt)].compactMap { $0 }.joined(separator: "．"))
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            HStack(spacing: 0) {
                                // 筆記本左側紅色邊線
                                Rectangle().fill(Theme.chalkYellow.opacity(0.6)).frame(width: 3)
                                Theme.chalkboard
                            }
                        )
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $editingNote) { note in
            CourseNoteEditor(note: note, store: store)
        }
    }
}

struct CourseNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var note: CourseNote
    let store: CourseNotesStore
    @State private var confirmDelete = false

    private var isExisting: Bool {
        store.notes.contains { $0.id == note.id }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("課程名稱，例如：經濟學 第 5 週", text: $note.title)
                    .font(.headline)
                    .disabled(note.isDefault)   // 一般筆記的標題固定
                    .padding(12)
                    .background(Theme.chalkboard)
                    .cornerRadius(10)

                if !CourseStore.shared.courses.isEmpty {
                    WheelSelectRow(
                        title: "課程",
                        selection: $note.courseId,
                        options: [(UUID?.none, tr("不指定"))] + CourseStore.shared.courses.map { (Optional($0.id), tr($0.name)) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Theme.chalkboard)
                    .cornerRadius(10)
                }

                ZStack(alignment: .topLeading) {
                    if note.body.isEmpty {
                        Text("課堂重點、老師提到的考試範圍、待複習的地方…")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                    }
                    TextEditor(text: $note.body)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
                .background(Theme.chalkboard)
                .cornerRadius(10)

                if note.isDefault {
                    Label("這是預設的一般筆記，不能刪除", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                } else if isExisting {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("刪除這則筆記", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(isExisting ? tr("編輯筆記") : tr("新增筆記"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        store.save(note)
                        dismiss()
                    }
                    .disabled(note.title.trimmingCharacters(in: .whitespaces).isEmpty
                              && note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("確定要刪除這則筆記嗎？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("刪除", role: .destructive) {
                    store.delete(note)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// 左側選單「課程筆記」頁：列出所有筆記，可新增、編輯
struct CourseNotesPageView: View {
    @Environment(\.dismiss) private var dismiss

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
                Text("課程筆記")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Theme.chalkWhite)
                Spacer()
            }
            .padding(.horizontal, 8)

            ScrollView {
                CourseNotesSection()
                Spacer(minLength: 40)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
