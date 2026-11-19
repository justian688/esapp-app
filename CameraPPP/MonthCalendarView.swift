//
//  MonthCalendarView.swift
//  CameraPPP
//
//  首頁「本月課程」行事曆
//  ・金色實心點：那天有錄影
//  ・空心圈點：課程時間寫了「週X」的固定上課日
//  ・點一天：下方列出那天錄了哪些課
//

import SwiftUI

struct MonthCalendarView: View {
    @State private var store = CourseStore.shared
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var selectedDay: Date?
    @State private var notesStore = CourseNotesStore.shared
    @State private var editingNote: CourseNote?
    @AppStorage(AppLanguage.storageKey) private var appLanguage = AppLanguage.traditionalChinese.rawValue

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1   // 週日開始，跟台灣一般月曆一樣
        return c
    }()

    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayRow
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day) } else { Color.clear.frame(height: 30) }
                }
            }
            if let selectedDay {
                dayDetail(selectedDay)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .background(Theme.chalkboard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.chalkLine, lineWidth: 1))
        .accessibilityIdentifier("home_calendar")
    }

    // MARK: 標題列

    private var header: some View {
        HStack {
            Text(monthTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.chalkWhite)
            Spacer()
            Button { changeMonth(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 32, height: 28)
            }
            Button { changeMonth(1) } label: {
                Image(systemName: "chevron.right").frame(width: 32, height: 28)
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(Theme.chalkYellow)
    }

    private var weekdayRow: some View {
        let symbols = Translations.isEnglish ? ["S", "M", "T", "W", "T", "F", "S"] : ["日", "一", "二", "三", "四", "五", "六"]
        return HStack(spacing: 0) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in
                Text(s).font(.system(size: 11, weight: .medium)).foregroundColor(.gray).frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: 日期格

    private func dayCell(_ day: Date) -> some View {
        let isToday = cal.isDateInToday(day)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let recorded = !(recordedDays[cal.startOfDay(for: day)] ?? []).isEmpty || !notes(on: day).isEmpty
        let scheduled = scheduledWeekdays.contains(cal.component(.weekday, from: day))
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedDay = isSelected ? nil : day }
        } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular).monospacedDigit())
                    .foregroundColor(isSelected ? .black : (isToday ? Theme.chalkYellow : Theme.chalkWhite))
                ZStack {
                    if recorded {
                        Circle().fill(isSelected ? Color.black : Theme.chalkYellow).frame(width: 5, height: 5)
                    } else if scheduled {
                        Circle().stroke(isSelected ? Color.black : Theme.chalkYellow.opacity(0.6), lineWidth: 1).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.chalkYellow)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 8).stroke(Theme.chalkYellow.opacity(0.6), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// 點一天：有錄影、有筆記才列出來；沒有就只留「新增筆記」
    private func dayDetail(_ day: Date) -> some View {
        let names = recordedDays[cal.startOfDay(for: day)] ?? []
        let dayNotes = notes(on: day)
        let df = DateFormatter()
        df.locale = Locale(identifier: Translations.isEnglish ? "en_US" : "zh_Hant_TW")
        df.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(df.string(from: day))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.chalkYellow)
                if !names.isEmpty {
                    Label(names.joined(separator: "、"), systemImage: "video.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.chalkWhite)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            ForEach(dayNotes) { note in
                Button { editingNote = note } label: {
                    Label(note.title.isEmpty ? tr("未命名筆記") : note.title, systemImage: "note.text")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.chalkWhite)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            Button {
                editingNote = CourseNote(title: "", body: "", courseId: store.currentCourseId, day: cal.startOfDay(for: day))
            } label: {
                Label(tr("新增這天的筆記"), systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.chalkYellow)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("calendar_addNote")
        }
        .padding(.top, 4)
        .sheet(item: $editingNote) { note in
            CourseNoteEditor(note: note, store: notesStore)
        }
    }

    private func notes(on day: Date) -> [CourseNote] {
        notesStore.notes.filter { n in n.day.map { cal.isDate($0, inSameDayAs: day) } ?? false }
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

    /// 課程時間寫了「週一～週日／星期X」→ 每週那天標示（Calendar 的 weekday：1 = 週日）
    private var scheduledWeekdays: Set<Int> {
        let map: [Character: Int] = ["日": 1, "天": 1, "一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7]
        var out = Set<Int>()
        for course in store.courses {
            let s = course.schedule
            for prefix in ["週", "周", "星期", "禮拜"] {
                var rest = Substring(s)
                while let r = rest.range(of: prefix) {
                    let after = rest[r.upperBound...]
                    if let c = after.first, let w = map[c] { out.insert(w) }
                    rest = after
                }
            }
        }
        return out
    }

    private func changeMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.easeInOut(duration: 0.2)) { month = m; selectedDay = nil }
        }
    }
}
