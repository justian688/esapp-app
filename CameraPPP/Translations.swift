//
//  Translations.swift
//  CameraPPP
//
//  英文翻譯：中文原文 → en.lproj/Localizable.strings 裡的英文。
//  Text("中文") 這類會自動跟著 App 語言切換；
//  不會自動切換的字串（程式回傳的 String、三元運算、錯誤訊息…）用 tr() 包起來。
//

import Foundation

nonisolated enum Translations {
    static let englishBundle: Bundle? = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }()

    static var isEnglish: Bool {
        UserDefaults.standard.string(forKey: "appLanguage") == "en"
    }
}

/// 中文原文 → 目前 App 語言的文字（英文模式查 en.lproj，查不到就原樣顯示）
nonisolated func tr(_ s: String) -> String {
    guard Translations.isEnglish, let b = Translations.englishBundle else { return s }
    return b.localizedString(forKey: s, value: s, table: nil)
}

/// 有數字或文字要代入的句子，例如 trf("%lld 分鐘", 30)
nonisolated func trf(_ key: String, _ args: CVarArg...) -> String {
    String(format: tr(key), arguments: args)
}
