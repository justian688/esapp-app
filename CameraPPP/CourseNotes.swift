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
    var id = UUID()
    var title: String
    var body: String
    var updatedAt = Date()
    /// 這則筆記屬於哪一堂課（nil = 未指定）
    var courseId: UUID?
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
    }

    func save(_ note: CourseNote) {
        var updated = note
        updated.updatedAt = Date()
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = updated
        } else {
            notes.insert(updated, at: 0)
        }
        notes.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func notes(courseId: UUID) -> [CourseNote] {
        notes.filter { $0.courseId == courseId }
    }

    func count(courseId: UUID?) -> Int {
        notes.filter { $0.courseId == courseId }.count
    }

    func delete(_ note: CourseNote) {
        notes.removeAll { $0.id == note.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CourseNote].self, from: data) else { return }
        notes = decoded.sorted { $0.updatedAt > $1.updatedAt }
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
                            Image(systemName: "pencil.line")
                                .foregroundColor(.white)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title.isEmpty ? "未命名課程" : note.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if !note.body.isEmpty {
                                    Text(note.body)
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                Text([CourseStore.shared.course(id: note.courseId)?.name, Self.dateFormatter.string(from: note.updatedAt)].compactMap { $0 }.joined(separator: "．"))
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
                                Rectangle().fill(Color.red.opacity(0.3)).frame(width: 3)
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
                    .padding(12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                if !CourseStore.shared.courses.isEmpty {
                    HStack {
                        Text("課程")
                            .foregroundColor(.gray)
                        Spacer()
                        Picker("課程", selection: $note.courseId) {
                            Text("不指定").tag(UUID?.none)
                            ForEach(CourseStore.shared.courses) { course in
                                Text(course.name).tag(Optional(course.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.systemGray6))
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
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)

                if isExisting {
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
            .navigationTitle(isExisting ? "編輯筆記" : "新增筆記")
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
