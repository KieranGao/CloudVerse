import AppKit
import SwiftUI
import LyricsCore

private typealias GalleryState<Value> = SwiftUI.State<Value>

struct ThemeGalleryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    let resetPosition: () -> Void
    @GalleryState private var scene = PreviewScene.forest
    @GalleryState private var wallpaper: NSImage?
    @GalleryState private var wallpaperMessage = "示意场景，不会替换系统壁纸"
    @GalleryState private var previewPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            livePreview
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("壁纸融合系列").font(.system(size: 16, weight: .semibold))
                    Text("八种构图，不只是换一组颜色。").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("8 THEMES").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(LyricTheme.allCases.filter(\.isWallpaper)) { theme in themeTile(theme) }
            }
            appearanceControls
            desktopControls
            DisclosureGroup("保留的经典主题 · Aurora / Ink / Signal") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(LyricTheme.allCases.filter { !$0.isWallpaper }) { theme in themeTile(theme) }
                }.padding(.top, 14)
            }
            .font(.system(size: 12))
        }
    }

    private var livePreview: some View {
        VStack(spacing: 0) {
            ThemePreview(theme: preferences.theme, scene: scene, wallpaper: wallpaper, tone: preferences.inkTone, fontSize: preferences.fontSize, effects: preferences.effects, showTranslation: preferences.translation, showPrevious: preferences.showPrevious, showNext: preferences.nextLine, showMetadata: preferences.showMetadata, textAlignment: preferences.alignment, anchor: preferences.anchor, live: previewPlaying, opacity: preferences.opacity, layoutWidth: preferences.width, canvasSize: NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900), motionEnabled: preferences.animate, fontChoice: preferences.fontChoice)
                .overlay(alignment: .topLeading) {
                    Text(preferences.theme.title).font(.system(size: 10, weight: .medium)).tracking(1)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(.black.opacity(0.2), in: Capsule()).foregroundStyle(.white.opacity(0.85)).padding(15)
                }
            HStack(spacing: 10) {
                Picker("背景", selection: $scene) {
                    ForEach(PreviewScene.allCases) { scene in Text(scene.title).tag(scene) }
                }
                .labelsHidden().frame(width: 140)
                .onChange(of: scene) { selected in
                    if selected == .desktop {
                        wallpaper = WallpaperSample.current()
                        wallpaperMessage = wallpaper == nil ? "无法读取动态/受保护壁纸，使用示意背景" : "裁切静态示意；自由拖动位置和壁纸平铺方式不复现"
                    } else { wallpaperMessage = "示意场景，不会替换系统壁纸" }
                }
                Button { previewPlaying.toggle() } label: {
                    Image(systemName: previewPlaying ? "pause.fill" : "play.fill")
                }
                .help("播放本地原创歌词，预览换句和逐字效果")
                Spacer()
                Text(previewPlaying ? "本地演示 · 非当前歌曲" : "静态预览").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .bottom) {
            Text(wallpaperMessage).font(.system(size: 9)).foregroundStyle(.secondary).offset(y: 18)
        }
        .padding(.bottom, 12)
    }

    private func themeTile(_ theme: LyricTheme) -> some View {
        let example = PreviewScene.suggested(for: theme)
        return Button { choose(theme) } label: {
            VStack(alignment: .leading, spacing: 0) {
                ThemePreview(theme: theme, scene: example, tone: example.suggestedTone, fontSize: 64, showTranslation: true, showMetadata: false, anchor: theme.defaultsToCentered ? .lowerCenter : .lowerLeft)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(theme.title).font(.system(size: 13, weight: .semibold))
                        Text(theme.subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: preferences.theme == theme ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16)).foregroundStyle(preferences.theme == theme ? Color.accentColor : Color.secondary.opacity(0.3))
                }
                .padding(12)
            }
            .padding(6)
            .background(Color.primary.opacity(0.018), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(preferences.theme == theme ? Color.accentColor : Color.primary.opacity(0.07), lineWidth: preferences.theme == theme ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title)，\(theme.subtitle)")
        .accessibilityAddTraits(preferences.theme == theme ? [.isSelected] : [])
    }

    private func choose(_ theme: LyricTheme) {
        preferences.theme = theme
        if preferences.anchor != .custom { preferences.anchor = theme.defaultsToCentered ? .lowerCenter : .lowerLeft }
    }

    private var appearanceControls: some View {
        group("墨色与排版", icon: "textformat") {
            Picker("文字明暗", selection: $preferences.inkTone) {
                ForEach(InkTone.allCases) { tone in Text(tone.title).tag(tone) }
            }
            .pickerStyle(.segmented)
            .disabled(!preferences.theme.isWallpaper)
            Text("深色壁纸用浅色字，浅色壁纸用深色字。浮雕和颗粒是字面效果，不会改写壁纸像素。").font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("字形", selection: $preferences.fontChoice) {
                ForEach(FontChoice.allCases) { font in Text(font.title).tag(font) }
            }.disabled(!preferences.theme.isWallpaper)
            adjustment("歌词字号", value: $preferences.fontSize, range: 20...72, text: "\(Int(preferences.fontSize)) pt")
            adjustment("排版宽度", value: $preferences.width, range: 420...1400, text: "\(Int(preferences.width)) px")
            adjustment("墨色透明度", value: $preferences.opacity, range: 0.3...1, text: "\(Int(preferences.opacity * 100))%")
            adjustment("字面质感强度", value: $preferences.effects, range: 0...1, text: "\(Int(preferences.effects * 100))%")
            Picker("文字对齐", selection: $preferences.alignment) {
                ForEach(LyricAlignment.allCases) { alignment in Text(alignment.title).tag(alignment) }
            }
            .disabled(!preferences.theme.isWallpaper)
            Divider()
            HStack(spacing: 30) {
                Toggle("显示翻译", isOn: $preferences.translation)
                Toggle("显示歌名 / 歌手", isOn: $preferences.showMetadata)
            }
            HStack(spacing: 30) {
                Toggle("淡显上一句", isOn: $preferences.showPrevious)
                Toggle("淡显下一句", isOn: $preferences.nextLine)
            }
            Toggle("柔和换句动画（遵循系统减少动态效果设置）", isOn: $preferences.animate)
            if preferences.theme == .aurora { Toggle("从专辑封面取色", isOn: $preferences.albumColor) }
            Text("普通 LRC 自动适配长句；极端长句可解锁后滚动查看。真实 YRC 使用同色系亮度推进，不伪造逐字时间。").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var desktopControls: some View {
        group("融入桌面", icon: "macwindow") {
            Picker("显示层级", selection: $preferences.layer) {
                ForEach(DesktopLayer.allCases) { layer in Text(layer.title).tag(layer) }
            }.pickerStyle(.segmented)
            Text("桌面模式在壁纸上、普通应用窗口下方；不会覆盖工作窗口，也不修改壁纸文件。全屏应用和桌面管理工具可能遮住它，可切回置顶模式。").font(.system(size: 11)).foregroundStyle(.secondary)
            Picker("留白位置", selection: $preferences.anchor) {
                ForEach(DesktopAnchor.allCases) { anchor in Text(anchor.title).tag(anchor) }
            }
            HStack {
                Button(preferences.locked ? "解锁后直接拖动" : "锁定并穿透鼠标") {
                    preferences.positioning = false
                    preferences.locked.toggle()
                }
                Button("按主题重置位置", action: resetPosition)
            }
            Text("解锁后直接拖动歌词任意位置；右键锁定或菜单栏点锁定即可恢复穿透。无需进入额外定位模式。").font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Toggle("显示桌面歌词", isOn: $preferences.visible)
            Toggle("锁定位置 / 穿透鼠标", isOn: $preferences.locked)
        }
    }

    private func group<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold))
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 13))
    }

    private func adjustment(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
