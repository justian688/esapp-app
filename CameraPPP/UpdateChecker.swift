//
//  UpdateChecker.swift
//  CameraPPP
//
//  版本檢查（強制更新）
//  每次打開 App 讀一個版本設定檔（放在 GitHub 公開專案 justian688/esapp-app 的 version.json）：
//  {
//    "minVersion": "1.7.1",      低於這個版本 → 擋住整個畫面，一定要更新才能繼續用
//    "latestVersion": "1.7.1",   低於這個版本 → 提醒有新版，可以按「稍後」
//    "message": "更新說明（選填）"
//  }
//  讀不到設定檔（沒網路）就不擋，避免使用者在沒網路時不能用。
//  App Store 網址自動用 Apple 的查詢服務取得，不用寫死。
//

import SwiftUI

@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable { case ok, optional, required }

    @Published var state: State = .ok
    @Published var message: String = ""
    private var storeURL: URL?

    static let configURL = URL(string: "https://raw.githubusercontent.com/justian688/esapp-app/main/version.json")!
    static let bundleID = "com.lin.energysaving"

    private struct Config: Decodable {
        let minVersion: String?
        let latestVersion: String?
        let message: String?
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check() async {
        var req = URLRequest(url: Self.configURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.httpMethod = "GET"
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let cfg = try? JSONDecoder().decode(Config.self, from: data) else { return }

        message = cfg.message ?? ""
        if let min = cfg.minVersion, Self.compare(currentVersion, min) < 0 {
            state = .required
        } else if let latest = cfg.latestVersion, Self.compare(currentVersion, latest) < 0 {
            state = .optional
        } else {
            state = .ok
        }
        if state != .ok { await loadStoreURL() }
    }

    func openStore() {
        let fallback = URL(string: "itms-apps://apps.apple.com/tw/search?term=es%E7%9C%81%E9%9B%BB%E7%8E%8B")!
        UIApplication.shared.open(storeURL ?? fallback)
    }

    private func loadStoreURL() async {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(Self.bundleID)&country=tw"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first,
              let link = first["trackViewUrl"] as? String else { return }
        storeURL = URL(string: link)
    }

    /// 比較版本號：1.7.1 vs 1.10.0
    static func compare(_ a: String, _ b: String) -> Int {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let d = (i < x.count ? x[i] : 0) - (i < y.count ? y[i] : 0)
            if d != 0 { return d }
        }
        return 0
    }
}

/// 需要強制更新時蓋住整個 App 的畫面
struct ForceUpdateView: View {
    @ObservedObject var checker: UpdateChecker

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.chalkYellow)
                Text(AppLanguage.current.localized("Update required", "需要更新"))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(checker.message.isEmpty
                     ? AppLanguage.current.localized("This version is no longer supported. Please update to the latest version to continue.",
                                                     "這個版本已停止支援，請更新到最新版本才能繼續使用。")
                     : checker.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 32)
                Button {
                    checker.openStore()
                } label: {
                    Text(AppLanguage.current.localized("Update now", "前往更新"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                        .background(Theme.chalkYellow, in: Capsule())
                }
                .padding(.top, 8)
            }
        }
    }
}
