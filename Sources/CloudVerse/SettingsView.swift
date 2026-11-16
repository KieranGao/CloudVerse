import SwiftUI
import AppKit
import LyricsCore

private typealias ViewState<Value> = SwiftUI.State<Value>

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    let resetPosition: () -> Void
    @ViewState private var section = SettingsSection.appearance
    @ViewState private var query = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 184)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heading
                    switch section {
                    case .appearance: appearance
                    case .lyrics: lyrics
                    case .connection: connection
                    }
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 780, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 22, weight: .light)).foregroundStyle(Color(red: 0.55, green: 0.48, blue: 0.96))
                VStack(alignment: .leading, spacing: 3) {
                    Text("CloudVerse").font(.system(size: 15, weight: .bold))
                    Text("YOUR MUSIC, YOUR SPACE").font(.system(size: 6, weight: .medium)).tracking(1)
                }
            }
            .padding(.bottom, 30)
            ForEach(SettingsSection.allCases) { tab in
                Button { section = tab } label: {
                    Label(tab.title, systemImage: tab.icon)
                        .font(.system(size: 12, weight: section == tab ? .semibold : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(section == tab ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Circle().fill(model.snapshot == nil ? Color.orange : (model.isDemo ? Color.purple : Color.green)).frame(width: 6, height: 6)
            Text(model.isDemo ? "演示模式" : (model.snapshot == nil ? "等待连接" : "已获取播放信息")).font(.system(size: 11, weight: .medium))
            Text("0.3 · 居中与控制面板版").font(.system(size: 10)).foregroundStyle(.secondary).padding(.top, 6)
            Divider().padding(.vertical, 6)
            GitHubAuthorLink()
        }
        .padding(20)
        .background(Color.primary.opacity(0.025))
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(section.title).font(.system(size: 27, weight: .bold))
            Text(section.description).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var appearance: some View {
        ThemeGalleryView(model: model, preferences: preferences, resetPosition: resetPosition)
    }

    private var lyrics: some View {
        VStack(alignment: .leading, spacing: 20) {
            controls {
                Label(model.snapshot?.track.title ?? "尚未连接播放器", systemImage: "music.note").font(.system(size: 14, weight: .semibold))
                Text(model.snapshot?.track.artist ?? "").font(.system(size: 12)).foregroundStyle(.secondary)
                Text(model.lyricStatus).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                slider("同步偏移", value: $preferences.offset, range: -10...10, text: String(format: "%+.1f s", preferences.offset))
                Text("正值使歌词提前显示；负值使歌词延后显示。").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Button("归零") { preferences.offset = 0 }
                    Button("重新匹配") { model.reloadLyrics() }.disabled(model.snapshot == nil || model.isDemo)
                    Button("导入 LRC / YRC") { model.importLyrics() }.disabled(model.snapshot == nil)
                }
            }
            Text("确认歌曲版本").font(.system(size: 15, weight: .semibold))
            HStack {
                TextField("歌曲名或歌手", text: $query).textFieldStyle(.roundedBorder).onSubmit { model.searchManual(query) }
                Button("搜索") { model.searchManual(query) }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || model.isLoading || model.isDemo)
            }
            if model.isLoading { ProgressView().controlSize(.small) }
            ForEach(model.candidates) { song in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(song.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Text("\(song.artist) · \(song.album)").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(duration(song.duration)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    Button(model.selectedSong?.id == song.id ? "已选" : "使用") { model.select(song) }
                        .disabled(model.isLoading || model.selectedSong?.id == song.id)
                }
                .padding(12).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
            }
            Text("自动匹配只接受歌名、歌手和时长接近的版本。翻唱、现场版或同名歌请手动确认。普通 LRC 仅逐行高亮；只有真实 YRC 数据才逐字高亮。").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 20) {
            controls {
                Label(model.isDemo ? "正在使用演示数据" : "播放器连接", systemImage: "antenna.radiowaves.left.and.right").font(.system(size: 14, weight: .semibold))
                Text(model.playbackStatus).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
                HStack {
                    Button("授权辅助功能") { PlaybackReader.requestPermission() }
                    Button("重新检测") { model.poll() }.disabled(model.isDemo)
                }
                Button("打开系统辅助功能设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                }
            }
            controls {
                Text("先看看歌词效果").font(.system(size: 14, weight: .semibold))
                Text("演示使用本地原创歌词与模拟逐字时间轴，不请求网络、不控制网易云音乐。").font(.system(size: 12)).foregroundStyle(.secondary)
                Button(model.isDemo ? "退出演示，连接播放器" : "开启演示模式") { model.toggleDemo() }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("兼容性与隐私").font(.system(size: 15, weight: .semibold))
                Text("此应用不修改网易云文件，不注入代码，不读取账号或 Cookie。歌词搜索会将当前歌名和歌手发送给网易云的非官方接口，接口可能变更或限流。仅缓存歌词用于本地显示。").font(.system(size: 12))
                Toggle("启用本地 Perl 播放兼容性适配", isOn: $preferences.bridgeEnabled)
                Text("直接读取受限时，本应用启动 /usr/bin/perl 子进程，加载随 App 打包的播放模块查询系统正在播放信息；不修改系统文件、不向网易云注入代码。此方法和 MediaRemote 都不是公开稳定接口，系统更新可能使其失效，不适用于 App Store 沙盒分发。").font(.system(size: 12))
                Text("浏览器播放视频可能占用系统媒体源，此时请回网易云点击播放后重新同步。控制会核验来源并回读变化，但底层是系统全局私有媒体接口，源切换的瞬间仍有竞态风险。关闭适配后可尝试辅助功能读取，部分客户端不支持。").font(.system(size: 12))
                Text("当前无需 Xcode：在项目目录运行 swift run CoreChecks 验证，运行 bash scripts/build-app.sh 打包，随后打开 dist/CloudVerse.app。未申请 Mac App Store 上架支持。").font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func controls<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func duration(_ value: Double) -> String { String(format: "%d:%02d", Int(value) / 60, Int(value) % 60) }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance, lyrics, connection
    var id: String { rawValue }
    var title: String {
        switch self { case .appearance: return "外观与主题"; case .lyrics: return "歌词与同步"; case .connection: return "连接与权限" }
    }
    var icon: String {
        switch self { case .appearance: return "paintpalette"; case .lyrics: return "text.quote"; case .connection: return "link" }
    }
    var description: String {
        switch self {
        case .appearance: return "让歌词融入桌面，而不是打断你的节奏。"
        case .lyrics: return "找到正确的版本，让每一句恰好出现。"
        case .connection: return "清楚地了解数据来自哪里，以及何时不可用。"
        }
    }
}
