//
//  SwipeBackEnabler.swift
//  CameraPPP
//
//  各頁都用自訂的返回鍵（隱藏了系統導覽列），iOS 會因此關掉
//  「從螢幕左邊往右滑回上一頁」的手勢。這裡把它打開回來，
//  設定、支援、課程資訊表、拍照設定…所有從側邊欄打開的頁面都能滑動返回。
//

import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    /// 只有在有上一頁可回時才啟動，避免在根頁面滑動造成畫面卡住
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
