//
//  AlbumLock.swift
//  CameraPPP
//
//  相簿密碼鎖
//  ・4 位數密碼（雜湊後存在鑰匙圈，不存明碼）＋可選 Face ID
//  ・課程相簿、單一課程頁、課程剪輯打開前要解鎖；App 一退到背景就重新上鎖
//  ・連續輸錯：第 3 次起暫停 1 分 → 5 分 → 15 分 → 60 分（跟 iPhone 解鎖一樣）
//  ・「輸錯 N 次清除相簿」是選擇性設定，預設關閉
//

import SwiftUI
import Observation
import CryptoKit
import LocalAuthentication
import Security

@MainActor
@Observable
final class AlbumLock {
    static let shared = AlbumLock()

    static let enabledKey = "albumLockEnabled"
    static let faceIDKey = "albumLockFaceID"
    static let eraseAfterKey = "albumLockEraseAfter"   // 0 = 關閉
    private static let failuresKey = "albumLockFailures"
    private static let lockedUntilKey = "albumLockLockedUntil"
    private static let keychainService = "com.lin.energysaving.albumlock"

    /// 這次打開 App 是否已解鎖（退到背景就清掉）
    private(set) var isUnlocked = false

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) && storedHash != nil }
    var useFaceID: Bool { UserDefaults.standard.bool(forKey: Self.faceIDKey) }
    var eraseAfter: Int { UserDefaults.standard.integer(forKey: Self.eraseAfterKey) }
    var failures: Int { UserDefaults.standard.integer(forKey: Self.failuresKey) }

    var lockedUntil: Date? {
        let t = UserDefaults.standard.double(forKey: Self.lockedUntilKey)
        return t > Date().timeIntervalSince1970 ? Date(timeIntervalSince1970: t) : nil
    }

    var needsUnlock: Bool { isEnabled && !isUnlocked }

    func relock() { isUnlocked = false }

    // MARK: 設定密碼

    func setPasscode(_ code: String) {
        let salt = UUID().uuidString
        saveKeychain(salt + ":" + Self.hash(code, salt: salt))
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        resetFailures()
        isUnlocked = true
    }

    func disable() {
        deleteKeychain()
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
        resetFailures()
        isUnlocked = false
    }

    // MARK: 解鎖

    enum Result { case ok, wrong(left: Int?), lockedOut(until: Date), erased }

    func tryUnlock(_ code: String) -> Result {
        if let until = lockedUntil { return .lockedOut(until: until) }
        guard let stored = storedHash, let sep = stored.firstIndex(of: ":") else { return .ok }
        let salt = String(stored[..<sep]), hash = String(stored[stored.index(after: sep)...])
        if Self.hash(code, salt: salt) == hash {
            resetFailures()
            isUnlocked = true
            return .ok
        }
        let n = failures + 1
        UserDefaults.standard.set(n, forKey: Self.failuresKey)
        // 選擇性：輸錯太多次清除相簿
        if eraseAfter > 0 && n >= eraseAfter {
            Task { await Self.eraseAlbum() }
            disable()
            return .erased
        }
        // 第 3 次起暫停：1 分、5 分、15 分、之後每次 60 分
        if n >= 3 {
            let minutes = [1, 5, 15][safe: n - 3] ?? 60
            let until = Date().addingTimeInterval(Double(minutes * 60))
            UserDefaults.standard.set(until.timeIntervalSince1970, forKey: Self.lockedUntilKey)
            return .lockedOut(until: until)
        }
        return .wrong(left: eraseAfter > 0 ? eraseAfter - n : nil)
    }

    func unlockWithBiometrics() async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else { return false }
        let ok = (try? await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                localizedReason: tr("解鎖課程相簿"))) ?? false
        if ok { resetFailures(); isUnlocked = true }
        return ok
    }

    static var biometricsAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private func resetFailures() {
        UserDefaults.standard.set(0, forKey: Self.failuresKey)
        UserDefaults.standard.set(0, forKey: Self.lockedUntilKey)
    }

    /// 刪除相簿裡所有影片、照片（無法復原）
    static func eraseAlbum() async {
        let videos = await StorageManager.shared.fetchAllMedia()
        let photos = await StorageManager.shared.fetchAllPhotos()
        let urls = videos + photos
        for url in urls {
            try? FileManager.default.removeItem(at: url)
            CourseStore.shared.forget(fileURL: url)
        }
    }

    // MARK: 雜湊、鑰匙圈

    private static func hash(_ code: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + code).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private var storedHash: String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: Self.keychainService,
                                kSecReturnData as String: true]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private func saveKeychain(_ value: String) {
        deleteKeychain()
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: Self.keychainService,
                                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                kSecValueData as String: Data(value.utf8)]
        SecItemAdd(q as CFDictionary, nil)
    }

    private func deleteKeychain() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: Self.keychainService]
        SecItemDelete(q as CFDictionary)
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - 套在要保護的頁面上

extension View {
    /// 相簿密碼鎖：沒解鎖前蓋一層密碼畫面
    func albumLocked() -> some View { modifier(AlbumLockGate()) }
}

private struct AlbumLockGate: ViewModifier {
    @State private var lock = AlbumLock.shared

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(lock.needsUnlock ? 0 : 1)
                .allowsHitTesting(!lock.needsUnlock)
            if lock.needsUnlock {
                PasscodeScreen(mode: .unlock)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - 密碼畫面（解鎖／設定）

struct PasscodeScreen: View {
    enum Mode { case unlock, create }
    let mode: Mode
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var lock = AlbumLock.shared
    @State private var code = ""
    @State private var firstEntry: String?
    @State private var message = ""
    @State private var shake = false
    @State private var showForgot = false
    @State private var now = Date()

    private var title: String {
        switch mode {
        case .unlock: return tr("輸入相簿密碼")
        case .create: return firstEntry == nil ? tr("設定 4 位數密碼") : tr("再輸入一次確認")
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 34))
                .foregroundColor(Theme.chalkYellow)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.chalkWhite)
            HStack(spacing: 18) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .stroke(Theme.chalkWhite.opacity(0.6), lineWidth: 1.5)
                        .background(Circle().fill(i < code.count ? Theme.chalkWhite : .clear))
                        .frame(width: 14, height: 14)
                }
            }
            .offset(x: shake ? -10 : 0)
            .animation(shake ? .default.repeatCount(3, autoreverses: true).speed(4) : .default, value: shake)

            Text(lockoutText ?? message)
                .font(.footnote)
                .foregroundColor(.red.opacity(0.85))
                .frame(minHeight: 18)

            keypad
                .disabled(lockoutText != nil)
                .opacity(lockoutText != nil ? 0.35 : 1)

            HStack {
                if mode == .unlock {
                    Button(tr("忘記密碼")) { showForgot = true }
                        .accessibilityIdentifier("passcode_forgot")
                } else {
                    Button(tr("取消")) { dismiss() }
                }
                Spacer()
                if mode == .unlock && lock.useFaceID && AlbumLock.biometricsAvailable {
                    Button { Task { await lock.unlockWithBiometrics() } } label: {
                        Label("Face ID", systemImage: "faceid")
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(Theme.chalkYellow)
            .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .task {
            if mode == .unlock && lock.useFaceID { _ = await lock.unlockWithBiometrics() }
        }
        .task {
            while !Task.isCancelled {   // 倒數暫停時間
                now = Date()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        .confirmationDialog(tr("忘記密碼？"), isPresented: $showForgot, titleVisibility: .visible) {
            if lock.useFaceID && AlbumLock.biometricsAvailable {
                Button(tr("用 Face ID 驗證後重設密碼")) {
                    Task {
                        if await lock.unlockWithBiometrics() { lock.disable() }
                    }
                }
            }
            Button(tr("清除相簿並重設密碼"), role: .destructive) {
                Task { await AlbumLock.eraseAlbum(); lock.disable() }
            }
            Button(tr("取消"), role: .cancel) {}
        } message: {
            Text(lock.useFaceID ? tr("可以用 Face ID 驗證後關閉密碼再重設。") : tr("沒有開啟 Face ID 時，只能清除相簿裡所有影片和照片才能重設，清除後無法復原。"))
        }
    }

    private var lockoutText: String? {
        guard mode == .unlock, let until = lock.lockedUntil, until > now else { return nil }
        let s = Int(until.timeIntervalSince(now))
        return trf("輸錯太多次，請 %lld:%02lld 後再試", s / 60, s % 60)
    }

    private var keypad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 72, height: 72)
                        } else {
                            Button { press(key) } label: {
                                Text(key)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(Theme.chalkWhite)
                                    .frame(width: 72, height: 72)
                                    .background(key == "⌫" ? Color.clear : Theme.chalkboard, in: Circle())
                            }
                            .accessibilityIdentifier("passcode_\(key)")
                        }
                    }
                }
            }
        }
    }

    private func press(_ key: String) {
        if key == "⌫" { if !code.isEmpty { code.removeLast() }; return }
        guard code.count < 4 else { return }
        code += key
        message = ""
        guard code.count == 4 else { return }
        let entered = code
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { submit(entered) }
    }

    private func submit(_ entered: String) {
        code = ""
        switch mode {
        case .create:
            if let first = firstEntry {
                if first == entered {
                    lock.setPasscode(entered)
                    onFinished?()
                    dismiss()
                } else {
                    firstEntry = nil
                    message = tr("兩次輸入不一樣，請重新設定")
                    wrongShake()
                }
            } else {
                firstEntry = entered
            }
        case .unlock:
            switch lock.tryUnlock(entered) {
            case .ok: break
            case .wrong(let left):
                message = left.map { trf("密碼錯誤，再錯 %lld 次會清除相簿", $0) } ?? tr("密碼錯誤")
                wrongShake()
            case .lockedOut: wrongShake()
            case .erased: message = tr("輸錯太多次，相簿已清除")
            }
        }
    }

    private func wrongShake() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        shake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
    }
}
