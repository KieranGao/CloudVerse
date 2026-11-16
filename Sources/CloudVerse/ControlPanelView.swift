import AppKit
import SwiftUI
import LyricsCore

struct ControlPanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    let openSettings: () -> Void
    let resetPosition: () -> Void
    let dismiss: () -> Void
    var panelHeight: Double = 690

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                nowPlaying
                transport
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("桌面歌词").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    HStack {
                        quickToggle("歌词", icon: "text.quote", active: preferences.visible) { preferences.visible.toggle() }
                        quickToggle(preferences.locked ? "锁定" : "可拖动", icon: preferences.locked ? "lock" : "hand.draw", active: preferences.locked) {
                            preferences.positioning = false
                            preferences.locked.toggle()
                            if !preferences.locked { dismiss() }
                        }
                        quickToggle("翻译", icon: "character.bubble", active: preferences.translation) { preferences.translation.toggle() }
                        quickToggle("置顶", icon: "pin", active: preferences.layer == .floating) { preferences.layer = preferences.layer == .desktop ? .floating : .desktop }
                    }
                    Picker("主题", selection: $preferences.theme) {
                        ForEach(LyricTheme.allCases) { theme in Text(theme.title).tag(theme) }
                    }
                    Picker("字形", selection: $preferences.fontChoice) {
                        ForEach(FontChoice.allCases) { font in Text(font.title).tag(font) }
                    }.disabled(!preferences.theme.isWallpaper)
                    HStack {
                        Text("字号").font(.system(size: 12))
                        Slider(value: $preferences.fontSize, in: 20...72)
                        Text("\(Int(preferences.fontSize))").font(.system(size: 11, design: .monospaced)).frame(width: 25)
                    }
                    HStack {
                        Text("同步偏移").font(.system(size: 12))
                        Spacer()
                        Button("−0.2") { preferences.offset = max(-10, preferences.offset - 0.2) }
                        Button(String(format: "%+.1f s", preferences.offset)) { preferences.offset = 0 }.help("点击归零")
                        Button("+0.2") { preferences.offset = min(10, preferences.offset + 0.2) }
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Circle().fill(model.reconnecting || model.snapshot == nil ? Color.orange : Color.green).frame(width: 5, height: 5)
                        Text(model.displayStatus).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(3)
                        Spacer(minLength: 0)
                        if model.isLoading { ProgressView().controlSize(.mini) }
                    }
                    if !model.controlStatus.isEmpty {
                        Text(model.controlStatus).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if !model.candidates.isEmpty && model.document.lines.isEmpty && !model.isLoading {
                        Menu("选择其他歌词版本") {
                            ForEach(model.candidates) { song in
                                Button("\(song.title) · \(song.artist)") { model.select(song) }
                            }
                        }
                    }
                    HStack {
                        Button("重新同步") { model.reloadLyrics(forceRefresh: true); model.poll() }.disabled(model.isDemo || model.isLoading)
                        Button("居中复位", action: resetPosition)
                        Spacer()
                        Button { model.toggleDemo() } label: { Image(systemName: "sparkles") }.help(model.isDemo ? "退出演示" : "本地演示")
                    }.controlSize(.small)
                }
                HStack {
                    Button("主题工作室…", action: openSettings)
                    Button("打开网易云") {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.netease.163music") {
                            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                        }
                    }
                    Spacer()
                    Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help("退出 CloudVerse")
                }.font(.system(size: 11))
            }
            .padding(20)
        }
        .frame(width: 370, height: panelHeight)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack {
            Image(systemName: "waveform").foregroundStyle(Color.accentColor)
            Text("CloudVerse").font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(model.isDemo ? "DEMO" : "网易云音乐").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    private var nowPlaying: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Group {
                    if let artwork = model.artwork {
                        Image(nsImage: artwork).resizable().scaledToFill()
                    } else {
                        ZStack { LinearGradient(colors: [.indigo.opacity(0.35), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing); Image(systemName: "music.note").font(.system(size: 20)).foregroundStyle(.white.opacity(0.8)) }
                    }
                }.frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.snapshot?.track.title ?? "等待播放器").font(.system(size: 14, weight: .semibold)).lineLimit(2)
                    Text(model.snapshot?.track.artist ?? "打开网易云音乐开始播放").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let position = max(0, model.position(at: context.date) - preferences.offset)
                let duration = model.snapshot?.track.duration ?? 0
                VStack(spacing: 6) {
                    ProgressView(value: min(position, max(1, duration)), total: max(1, duration)).tint(.accentColor)
                    HStack {
                        Text(time(position))
                        Spacer()
                        Text(time(duration))
                    }.font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    if let index = model.document.index(at: model.position(at: context.date)) {
                        Text(model.document.lines[index].text).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 30) {
            Button { model.send(.previous) } label: { Image(systemName: "backward.end.fill").font(.system(size: 19)) }.help("上一首（可能先回到当前曲开头）")
            Button { model.send(model.isPlaying ? .pause : .play) } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 19))
                    .frame(width: 44, height: 44).background(Color.accentColor.opacity(0.12), in: Circle())
            }.help(model.isPlaying ? "暂停" : "播放")
            Button { model.send(.next) } label: { Image(systemName: "forward.end.fill").font(.system(size: 19)) }.help("下一首")
        }
        .buttonStyle(.plain)
        .disabled(!model.canControl)
        .frame(maxWidth: .infinity)
    }

    private func quickToggle(_ title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13))
                Text(title).font(.system(size: 9))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .foregroundStyle(active ? Color.accentColor : Color.secondary)
            .background(active ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
    }

    private func time(_ value: Double) -> String {
        let seconds = value.isFinite ? max(0, Int(value)) : 0
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
