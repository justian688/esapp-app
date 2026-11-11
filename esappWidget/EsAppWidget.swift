//
//  EsAppWidget.swift
//  esappWidget
//
//  主畫面／鎖定畫面小工具與控制中心按鈕：點一下打開 es省電王 並開始錄影
//  （iOS 不允許小工具在背景直接開相機，所以會先打開 App）
//

import AppIntents
import SwiftUI
import WidgetKit

private let recordURL = URL(string: "esapp://record")!

struct RecordEntry: TimelineEntry {
    let date: Date
}

struct RecordProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecordEntry {
        RecordEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecordEntry) -> Void) {
        completion(RecordEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecordEntry>) -> Void) {
        completion(Timeline(entries: [RecordEntry(date: .now)], policy: .never))
    }
}

struct RecordWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "video.fill")
                    .font(.title3)
            }
        default:
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 56, height: 56)
                    Image(systemName: "video.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                Text("開始錄影")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("es省電王")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct RecordWidget: Widget {
    let kind = "EsAppRecordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecordProvider()) { _ in
            RecordWidgetView()
                .containerBackground(Color.black, for: .widget)
                .widgetURL(recordURL)
        }
        .configurationDisplayName("開始錄影")
        .description("點一下打開 es省電王 並立即開始省電錄影")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// 控制中心／鎖定畫面按鈕
struct RecordControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "EsAppRecordControl") {
            ControlWidgetButton(action: OpenURLIntent(recordURL)) {
                Label("開始錄影", systemImage: "video.fill")
            }
        }
        .displayName("es省電王 錄影")
        .description("打開 es省電王 並開始錄影")
    }
}

@main
struct EsAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecordWidget()
        RecordControl()
    }
}
