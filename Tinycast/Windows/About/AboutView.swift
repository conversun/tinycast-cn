import AppKit
import SwiftUI

struct AboutView: View {
    private static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return String(format: "Version %@ (%@)".localizedUI, short, build)
    }

    // Loaded once and cached: reading the .icns is disk I/O, and body can re-run often. Read the
    // bundled file directly since NSApp.applicationIconImage returns the generic placeholder until
    // LaunchServices registers the app, which it hasn't when run from build/.
    @MainActor private static let appIcon: NSImage = {
        if let name = Bundle.main.infoDictionary?["CFBundleIconFile"] as? String,
            let url = Bundle.main.url(forResource: name, withExtension: "icns"),
            let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }()

    private static let iconSize: CGFloat = 88

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                // A tighter block rhythm than `SettingsPane`'s `xxl` so hero, links and support all land above the fold of the fixed-height Settings window.
                VStack(spacing: Theme.Spacing.xl) {
                    hero
                    links
                    support
                }
                // Ignore the transparent-titlebar safe area and use one fixed `xxl` inset every side, matching `SettingsPane`.
                .padding(Theme.Spacing.xxl)
                .frame(maxWidth: .infinity)
                .overlayScroller()
            }
            // Outside the scroll view so the copyright stays pinned to the pane's bottom edge, the way a real About window reads.
            footer
                .padding(.bottom, Theme.Spacing.xxl)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(nsImage: Self.appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

            VStack(spacing: Theme.Spacing.sm) {
                Text(Bundle.main.appDisplayName)
                    .font(.title.weight(.bold))
                Text(Self.version)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs / 2)
                    .background(
                        Capsule().fill(Theme.Colors.cardFill)
                    )
                    .overlay(
                        Capsule().strokeBorder(Theme.Colors.cardStroke, lineWidth: 1)
                    )
            }

            Text("A tiny, native macOS launcher.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var links: some View {
        SettingsCard(header: "Links") {
            // Rows paint a full-bleed hover fill, so the stack is clipped to the card's corner — otherwise the first/last row's highlight squares off the rounded ends.
            VStack(spacing: 0) {
                ForEach(AboutLink.all) { link in
                    if link.id != AboutLink.all.first?.id { SettingsDivider() }
                    AboutLinkRow(link: link)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    // No section header: the callout's own title is the header.
    private var support: some View {
        SettingsCallout(
            title: "Buy Me Brave Origin",
            message:
                "If you enjoy my work and would like to support me or buy me Brave Origin, feel free to reach out on Discord, X, or via email.",
            systemImage: "bolt.fill",
            tint: Theme.Colors.brand
        )
    }

    private var footer: some View {
        Text("© 2026 Abue Ammar · Released under AGPL-3.0")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

/// One external destination in the About "Links" card.
private struct AboutLink: Identifiable {
    enum Glyph {
        case symbol(String)
        /// A brand mark from `Assets.xcassets` (template SVG) — SF Symbols ships no GitHub/Discord/X logo.
        case brand(String)
    }

    let id: String
    let glyph: Glyph
    let title: String
    let detail: String
    let url: URL

    static let all: [AboutLink] = [
        AboutLink(
            id: "website", glyph: .symbol("globe"), title: "Website",
            detail: "abue-ammar.github.io/tinycast",
            url: URL(string: "https://abue-ammar.github.io/tinycast/")!),
        AboutLink(
            id: "github", glyph: .brand("BrandGitHub"), title: "GitHub",
            detail: "github.com/abue-ammar/tinycast",
            url: URL(string: "https://github.com/abue-ammar/tinycast")!),
        AboutLink(
            id: "discord", glyph: .brand("BrandDiscord"), title: "Discord",
            detail: "Join the Tinycast community",
            url: URL(string: "https://discord.gg/v2Eeb4QQy3")!),
        AboutLink(
            id: "x", glyph: .brand("BrandX"), title: "X", detail: "@abue_ammar",
            url: URL(string: "https://x.com/abue_ammar")!),
        AboutLink(
            id: "email", glyph: .symbol("envelope"), title: "Email",
            detail: "iabueammar@gmail.com", url: URL(string: "mailto:iabueammar@gmail.com")!)
    ]
}

/// A tappable row inside the About "Links" card: glyph, title, the destination in plain text, and the external-link arrow.
private struct AboutLinkRow: View {
    let link: AboutLink

    @State private var hovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(link.url)
        } label: {
            HStack(spacing: Theme.Spacing.lg) {
                glyph
                    .frame(width: Theme.Size.settingsRowIcon)
                    .foregroundStyle(.secondary)
                Text(link.title.localizedUI)
                    .font(.body)
                Spacer(minLength: Theme.Spacing.xl)
                Text(link.detail.localizedUI)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hovered ? .secondary : .tertiary)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .background(hovered ? Theme.Colors.rowHover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    @ViewBuilder
    private var glyph: some View {
        switch link.glyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 13, weight: .medium))
        case .brand(let name):
            // Brand marks paint edge to edge, so they sit a point under the SF Symbol box to read the same weight.
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
        }
    }
}
