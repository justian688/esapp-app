//
//  MonthCalendarView.swift
//  CameraPPP
//
//  首頁月曆（比例縮小）：單純用來記筆記
//  ・格子裡寫當天第一則筆記的標題
//  ・點一天：從下方彈出那天的筆記，可新增當天筆記
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day, height: 44) } else { Color.clear.frame(height: 44) }
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
        let dayNotes = notes(on: day)
        let labels: [(String, Bool)] = dayNotes.map { ($0.title.isEmpty ? tr("筆記") : $0.title, false) }
        let maxLabels = 1
        let hasNote = !dayNotes.isEmpty
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

// MARK: - 點一天：那天的筆記

private struct DayDetailSheet: View {
    let day: Date
    @State private var store = CourseStore.shared
    @State private var notesStore = CourseNotesStore.shared
    @State private var editingNote: CourseNote?
    private let cal = Calendar(identifier: .gregorian)

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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(formatter("MMMMdEEEE").string(from: day))
                    .font(.title3.weight(.bold))
                    .foregroundColor(Theme.chalkWhite)
                    .padding(.top, 18)

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
    }
}
