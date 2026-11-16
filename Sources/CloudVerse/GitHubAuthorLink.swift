import AppKit
import SwiftUI

struct GitHubAuthorLink: View {
    var fontSize: Double = 11
    var iconSize: Double = 14

    private var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CloudVerseAuthor") as? String ?? "KieranGao"
    }

    private var destination: URL? {
        URL(string: Bundle.main.object(forInfoDictionaryKey: "CloudVerseAuthorURL") as? String ?? "https://github.com/KieranGao")
    }

    var body: some View {
        if let destination {
            Link(destination: destination) {
                label
            }
            .buttonStyle(.plain)
            .help("打开 \(name) 的 GitHub 主页")
            .accessibilityLabel("\(name)，打开 GitHub 主页")
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 6) {
            if let mark = Bundle.main.url(forResource: "GitHubMark", withExtension: "png").flatMap(NSImage.init(contentsOf:)) {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "link").font(.system(size: iconSize))
            }
            Text(name).font(.system(size: fontSize, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
    }
}
