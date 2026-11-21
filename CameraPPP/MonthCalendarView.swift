//
//  MonthCalendarView.swift
//  CameraPPP
//
//  首頁大月曆（像 Google 日曆月檢視）：填滿首頁中間，格子裡直接寫課名
//  ・金色小標籤：那天有錄影的課
//  ・灰色小標籤：課程時間寫了「週X」的固定上課日
//  ・小點：那天有筆記
//  ・點一天：從下方彈出那天的錄影、筆記，可新增當天筆記
//

import SwiftUI

struct MonthCalendarView: View {
    @State private var store = CourseStore.shared
    @State private var notesStore = CourseNotesStore.shared
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var selectedDay: Date?
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.traditionalChinese.rawValue

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1   // 週日開始，跟台灣一般月曆一樣
        return c
    }()

    var body: some View {
        VStack(spacing: 6) {
            header
            weekdayRow
            GeometryReader { geo in
                let rows = CGFloat(max(1, (cells.count + 6) / 7))
                let cellH = max(40, (geo.size.height - (rows - 1) * 3) / rows)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                        if let day { dayCell(day, height: cellH) } else { Color.clear.frame(height: cellH) }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Theme.chalkboard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.chalkLine, lineWidth: 1))
        .sheet(item: Binding(get: { selectedDay.map { DayRef(date: $0) } }, set: { selectedDay = $0?.date })) { ref in
            DayDetailSheet(day: ref.date)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .accessibilityIdentifier("home_calendar")
    }

    // MARK: 標題列

    private var header: some View {
        HStack {
            Text(monthTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.chalkWhite)
            Spacer()
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 30)
            }
            .accessibilityLabel(tr("上個月"))
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 30)
            }
            .accessibilityLabel(tr("下個月"))
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(Theme.chalkYellow)
        .padding(.leading, 6)
    }

    private var weekdayRow: some View {
        let symbols = Translations.isEnglish ? ["S", "M", "T", "W", "T", "F", "S"] : ["日", "一", "二", "三", "四", "五", "六"]
        return HStack(spacing: 3) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in
                Text(s).font(.system(size: 11, weight: .medium)).foregroundColor(.gray).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: 日期格（寫課名）

    private func dayCell(_ day: Date, height: CGFloat) -> some View {
        let isToday = cal.isDateInToday(day)
        let recorded = recordedDays[cal.startOfDay(for: day)] ?? []
        let weekday = cal.component(.weekday, from: day)
        let scheduled = (scheduledByWeekday[weekday] ?? []).filter { !recorded.contains($0) }
        let labels: [(String, Bool)] = recorded.map { ($0, true) } + scheduled.map { ($0, false) }
        let maxLabels = height >= 70 ? 2 : (height >= 52 ? 1 : 0)
        let hasNote = !notes(on: day).isEmpty
        return Button {
            selectedDay = day
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text("\(cal.component(.day, from: day))")
                        .font(.system(size: 12, weight: isToday ? .bold : .regular).monospacedDigit())
                        .foregroundColor(isToday ? Theme.chalkYellow : Theme.chalkWhite)
                    if hasNote {
                        Circle().fill(Theme.chalkYellow.opacity(0.8)).frame(width: 4, height: 4)
                    }
                }
                ForEach(Array(labels.prefix(maxLabels).enumerated()), id: \.offset) { _, item in
                    Text(item.0)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(item.1 ? .black : Theme.chalkWhite.opacity(0.85))
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(item.1 ? Theme.chalkYellow : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
                }
                if labels.count > maxLabels && maxLabels > 0 {
                    Text("+\(labels.count - maxLabels)").font(.system(size: 9)).foregroundColor(.gray)
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background {
                if isToday {
                    RoundedRectangle(cornerRadius: 8).stroke(Theme.chalkYellow.opacity(0.8), lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.025))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 資料

    private var monthTitle: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: Translations.isEnglish ? "en_US" : "zh_Hant_TW")
        df.setLocalizedDateFormatFromTemplate("yMMMM")
        return df.string(from: month)
    }

    /// 本月每一格（月初前補空白）
    private var cells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    /// 本月哪天錄了哪些課（課程名稱，同一天同一堂課只算一次）
    private var recordedDays: [Date: [String]] {
        guard let end = cal.date(byAdding: .month, value: 1, to: month) else { return [:] }
        var out: [Date: [String]] = [:]
        for r in store.media.values where r.kind == .video && r.recordedAt >= month && r.recordedAt < end {
            let day = cal.startOfDay(for: r.recordedAt)
            let name = tr(store.course(id: r.courseId)?.name ?? "未分類")
            if !(out[day] ?? []).contains(name) { out[day, default: []].append(name) }
        }
        return out
    }

    /// 課程時間寫了「週一～週日／星期X」→ 每週那天顯示課名（Calendar 的 weekday：1 = 週日）
    private var scheduledByWeekday: [Int: [String]] {
        let map: [Character: Int] = ["日": 1, "天": 1, "一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7]
        var out: [Int: [String]] = [:]
        for course in store.courses {
            let s = course.schedule
            for prefix in ["週", "周", "星期", "禮拜"] {
                var rest = Substring(s)
                while let r = rest.range(of: prefix) {
                    let after = rest[r.upperBound...]
                    if let c = after.first, let w = map[c] {
                        let name = tr(course.name)
                        if !(out[w] ?? []).contains(name) { out[w, default: []].append(name) }
                    }
                    rest = after
                }
            }
        }
        return out
    }

    private func notes(on day: Date) -> [CourseNote] {
        notesStore.notes.filter { n in n.day.map { cal.isDate($0, inSameDayAs: day) } ?? false }
    }

    private func changeMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) { month = m }
        }
    }
}

private struct DayRef: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

// MARK: - 點一天：那天的錄影和筆記

private struct DayDetailSheet: View {
    let day: Date
    @State private var store = CourseStore.shared
    @State private var notesStore = CourseNotesStore.shared
    @State private var editingNote: CourseNote?
    @State private var playing: IdentifiableURL?
    private let cal = Calendar(identifier: .gregorian)

    /// 錄影檔放在 App 的 SecureMedia 資料夾（跟 StorageManager 一樣）
    private var recordings: [(url: URL, record: MediaRecord)] {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SecureMedia", isDirectory: true)
        return store.media.values
            .filter { $0.kind == .video && cal.isDate($0.recordedAt, inSameDayAs: day) }
            .sorted { $0.recordedAt < $1.recordedAt }
            .compactMap { r in
                let url = dir.appendingPathComponent(r.fileName)
                return FileManager.default.fileExists(atPath: url.path) ? (url, r) : nil
            }
    }

    private var dayNotes: [CourseNote] {
        notesStore.notes.filter { n in n.day.map { cal.isDate($0, inSameDayAs: day) } ?? false }
    }

    private func formatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: Translations.isEnglish ? "en_US" : "zh_Hant_TW")
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }

    var body: some View {
        let tf = formatter("jmm")
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(formatter("MMMMdEEEE").string(from: day))
                    .font(.title3.weight(.bold))
                    .foregroundColor(Theme.chalkWhite)
                    .padding(.top, 18)

                ForEach(recordings, id: \.url) { item in
                    Button { playing = IdentifiableURL(url: item.url) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.circle.fill").font(.title3).foregroundColor(Theme.chalkYellow)
                            Text(tr(store.course(id: item.record.courseId)?.name ?? "未分類"))
                                .foregroundColor(Theme.chalkWhite)
                            Spacer()
                            Text(tf.string(from: item.record.recordedAt)).font(.footnote).foregroundColor(.gray)
                        }
                        .padding(12)
                        .background(Theme.chalkboard, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(dayNotes) { note in
                    Button { editingNote = note } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "note.text").foregroundColor(Theme.chalkYellow)
                            Text(note.title.isEmpty ? tr("未命名筆記") : note.title)
                                .foregroundColor(Theme.chalkWhite)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(12)
                        .background(Theme.chalkboard, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    editingNote = CourseNote(title: "", body: "", courseId: store.currentCourseId, day: cal.startOfDay(for: day))
                } label: {
                    Label(tr("新增這天的筆記"), systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.chalkYellow)
                        .padding(.vertical, 8)
                }
                .accessibilityIdentifier("calendar_addNote")
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $editingNote) { note in
            CourseNoteEditor(note: note, store: notesStore)
        }
        .fullScreenCover(item: $playing) { item in
            FullScreenVideoPlayer(videoURL: item.url)
        }
    }
}
