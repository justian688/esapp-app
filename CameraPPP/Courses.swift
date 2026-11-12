//
//  Courses.swift
//  CameraPPP
//
//  課程清單、目前課程，以及每段錄影／每張照片屬於哪一堂課
//

import Foundation
import Observation

struct Course: Identifiable, Codable, Hashable {
    static let defaultCategory = "一般課程"

    var id = UUID()
    var name: String
    /// 上課時間，例如「週四 09:10」
    var schedule: String = ""
    /// 教室，例如「B203」
    var room: String = ""
    /// 老師或講者
    var teacher: String = ""
    /// 分類，例如「學校課程」「演講」；沒建立分類時是「一般課程」
    var category: String = Course.defaultCategory
    var createdAt = Date()

    init(name: String, schedule: String = "", room: String = "", teacher: String = "", category: String = Course.defaultCategory) {
        self.name = name
        self.schedule = schedule
        self.room = room
        self.teacher = teacher
        self.category = category
    }

    // 舊版存的課程沒有老師、分類欄位，讀取時補上預設值
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        schedule = try c.decodeIfPresent(String.self, forKey: .schedule) ?? ""
        room = try c.decodeIfPresent(String.self, forKey: .room) ?? ""
        teacher = try c.decodeIfPresent(String.self, forKey: .teacher) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? Course.defaultCategory
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var detailLine: String {
        [schedule, room].filter { !$0.isEmpty }.joined(separator: "．")
    }
}

enum MediaKind: String, Codable {
    case video
    case photo
}

struct MediaRecord: Codable, Hashable {
    var fileName: String
    var kind: MediaKind
    var courseId: UUID?
    var recordedAt: Date
}

@Observable
final class CourseStore {
    static let shared = CourseStore()

    private(set) var courses: [Course] = []
    /// 使用者建立的分類（「一般課程」永遠存在，不用另外存）
    private(set) var customCategories: [String] = []
    private(set) var media: [String: MediaRecord] = [:]
    var currentCourseId: UUID? {
        didSet {
            UserDefaults.standard.set(currentCourseId?.uuidString, forKey: Self.currentCourseKey)
        }
    }

    private static let currentCourseKey = "currentCourseId"

    private static let categoriesKey = "courseCategories"
    private let coursesURL: URL
    private let mediaURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        coursesURL = dir.appendingPathComponent("courses.json")
        mediaURL = dir.appendingPathComponent("course_media.json")
        courses = Self.load([Course].self, from: coursesURL) ?? []
        media = Self.load([String: MediaRecord].self, from: mediaURL) ?? [:]
        customCategories = UserDefaults.standard.stringArray(forKey: Self.categoriesKey) ?? []
        if let raw = UserDefaults.standard.string(forKey: Self.currentCourseKey),
           let id = UUID(uuidString: raw),
           courses.contains(where: { $0.id == id }) {
            currentCourseId = id
        }
    }

    var currentCourse: Course? {
        guard let id = currentCourseId else { return nil }
        return courses.first { $0.id == id }
    }

    func course(id: UUID?) -> Course? {
        guard let id else { return nil }
        return courses.first { $0.id == id }
    }

    // MARK: - 分類

    /// 全部分類：一般課程在最前面，接著是使用者建立的
    var categories: [String] {
        [Course.defaultCategory] + customCategories
    }

    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !categories.contains(trimmed) else { return }
        customCategories.append(trimmed)
        UserDefaults.standard.set(customCategories, forKey: Self.categoriesKey)
    }

    /// 刪除分類：裡面的課程移回「一般課程」
    func deleteCategory(_ name: String) {
        guard name != Course.defaultCategory else { return }
        customCategories.removeAll { $0 == name }
        UserDefaults.standard.set(customCategories, forKey: Self.categoriesKey)
        for index in courses.indices where courses[index].category == name {
            courses[index].category = Course.defaultCategory
        }
        persistCourses()
    }

    func courses(in category: String) -> [Course] {
        courses.filter { $0.category == category || (category == Course.defaultCategory && !categories.contains($0.category)) }
    }

    // MARK: - 課程

    func save(_ course: Course) {
        if let index = courses.firstIndex(where: { $0.id == course.id }) {
            courses[index] = course
        } else {
            courses.append(course)
        }
        persistCourses()
    }

    /// 刪除課程：影片和照片不會刪掉，會移到「未分類」
    func delete(_ course: Course) {
        courses.removeAll { $0.id == course.id }
        for (name, record) in media where record.courseId == course.id {
            media[name]?.courseId = nil
        }
        if currentCourseId == course.id { currentCourseId = nil }
        persistCourses()
        persistMedia()
    }

    // MARK: - 影片與照片

    /// 存檔時呼叫：把這個檔案歸到目前選的課程
    func register(fileURL: URL, kind: MediaKind) {
        let name = fileURL.lastPathComponent
        media[name] = MediaRecord(fileName: name, kind: kind, courseId: currentCourseId, recordedAt: Date())
        persistMedia()
    }

    func move(fileURL: URL, to courseId: UUID?) {
        let name = fileURL.lastPathComponent
        if media[name] == nil {
            media[name] = MediaRecord(fileName: name, kind: fileURL.pathExtension.lowercased() == "mp4" ? .video : .photo, courseId: courseId, recordedAt: Date())
        } else {
            media[name]?.courseId = courseId
        }
        persistMedia()
    }

    func forget(fileURL: URL) {
        media[fileURL.lastPathComponent] = nil
        persistMedia()
    }

    func courseId(for url: URL) -> UUID? {
        media[url.lastPathComponent]?.courseId
    }

    /// 從全部檔案中挑出屬於某堂課的（nil = 未分類）
    func filter(_ urls: [URL], courseId: UUID?) -> [URL] {
        urls.filter { self.courseId(for: $0) == courseId }
    }

    func videoCount(courseId: UUID?) -> Int {
        media.values.filter { $0.kind == .video && $0.courseId == courseId }.count
    }

    func lastRecordedAt(courseId: UUID?) -> Date? {
        media.values.filter { $0.courseId == courseId }.map(\.recordedAt).max()
    }

    // MARK: - 存檔

    private func persistCourses() {
        Self.write(courses, to: coursesURL)
    }

    private func persistMedia() {
        Self.write(media, to: mediaURL)
    }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            print("課程資料儲存失敗：\(error)")
        }
    }
}

// MARK: - 顯示用的小工具

enum CourseFormat {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.dateFormat = "M/d"
        return f
    }()

    static let headerDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    static func relative(_ date: Date?) -> String {
        guard let date else { return "尚未錄影" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        return shortDate.string(from: date)
    }
}
