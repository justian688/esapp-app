//
//  SwipeBackEnabler.swift
//  CameraPPP
//
//  各頁都用自訂的返回鍵（隱藏了系統導覽列），iOS 會因此關掉
//  「從螢幕左邊往右滑回上一頁」的手勢。這裡把它打開回來。
//
//  做法：在導覽根畫面放一個看不見的小元件，找到所屬的導覽控制器後，
//  只替換「滑動返回手勢」的判斷者，不更動 iOS 導覽元件本身的程式（真機上較安全）。
//

import SwiftUI
import UIKit

final class SwipeBackDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBackDelegate()
    weak var navigationController: UINavigationController?

    /// 只有在有上一頁可回時才啟動，避免在根頁面滑動造成畫面卡住
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}

private struct SwipeBackHook: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HookController { HookController() }
    func updateUIViewController(_ vc: HookController, context: Context) { vc.attach() }

    final class HookController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attach()
        }
        func attach() {
            guard let nav = navigationController, let pop = nav.interactivePopGestureRecognizer else { return }
            SwipeBackDelegate.shared.navigationController = nav
            pop.delegate = SwipeBackDelegate.shared
            pop.isEnabled = true
        }
    }
}

extension View {
    /// 放在 NavigationStack 的根畫面上
    func enableSwipeBack() -> some View {
        background(SwipeBackHook().frame(width: 0, height: 0))
    }
}
