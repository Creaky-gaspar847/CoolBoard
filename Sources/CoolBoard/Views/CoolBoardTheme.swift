import SwiftUI

enum CoolBoardTheme {
    static let background = Color(red: 0.015, green: 0.015, blue: 0.016)
    static let panel = Color.white.opacity(0.045)
    static let panelStrong = Color.white.opacity(0.075)
    static let line = Color.white.opacity(0.18)
    static let lineMuted = Color.white.opacity(0.09)
    static let textMuted = Color.white.opacity(0.58)
    static let textSoft = Color.white.opacity(0.78)
    static let accent = Color.white
}

struct DividerLine: View {
    enum Axis {
        case horizontal
        case vertical
    }

    let axis: Axis

    var body: some View {
        Rectangle()
            .fill(CoolBoardTheme.lineMuted)
            .frame(
                width: axis == .vertical ? 1 : nil,
                height: axis == .horizontal ? 1 : nil
            )
    }
}

struct SectionHeader: View {
    let index: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(index)
                .foregroundStyle(.white)
            Text(title.uppercased())
                .foregroundStyle(CoolBoardTheme.textSoft)
            DividerLine(axis: .horizontal)
        }
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .tracking(1.2)
    }
}

struct TechnicalPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(CoolBoardTheme.panel)
            .overlay(
                Rectangle()
                    .stroke(CoolBoardTheme.lineMuted, lineWidth: 1)
            )
    }
}

struct PixelMark: View {
    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                pixel(true); pixel(false); pixel(true)
            }
            GridRow {
                pixel(false); pixel(true); pixel(false)
            }
            GridRow {
                pixel(true); pixel(false); pixel(true)
            }
        }
    }

    private func pixel(_ active: Bool) -> some View {
        Rectangle()
            .fill(active ? .white : .clear)
            .frame(width: 7, height: 7)
    }
}
