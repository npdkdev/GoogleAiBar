import SwiftUI
import Domain
import Infrastructure
#if ENABLE_SPARKLE
import Sparkle
#endif

/// Inline settings content view that fits within the menu bar popup.
struct SettingsContentView: View {
    @Binding var showSettings: Bool
    let monitor: QuotaMonitor
    @Environment(\.appTheme) private var theme
    @State private var settings = AppSettings.shared

    #if ENABLE_SPARKLE
    @Environment(\.sparkleUpdater) private var sparkleUpdater
    #endif

    @State private var providersExpanded: Bool = false
    @State private var antigravityConfigExpanded: Bool = false
    @State private var updatesExpanded: Bool = false
    @State private var backgroundSyncExpanded: Bool = false

    @State private var antigravityAccountsPathInput: String = ""
    @State private var antigravityFetchIntervalInput: String = ""

    // Hook settings state
    @State private var hooksExpanded: Bool = false
    @State private var hookEnabled: Bool = false
    @State private var hookPortInput: String = ""

    private enum ProviderID {
        static let gemini = "gemini"
        static let antigravity = "antigravity"
    }

    private var isAntigravityEnabled: Bool {
        monitor.provider(for: ProviderID.antigravity)?.isEnabled ?? false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)

            // Scrollable Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    themeCard
                    displayModeCard
                    overviewModeCard
                    providersCard
                    
                    if isAntigravityEnabled {
                        antigravityConfigCard
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    backgroundSyncCard
                    hooksCard
                    launchAtLoginCard
                    #if ENABLE_SPARKLE
                    updatesCard
                    #endif
                    logsCard
                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            // Footer
            footer
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(maxHeight: maxSettingsHeight)
        .onAppear {
            hookEnabled = UserDefaultsProviderSettingsRepository.shared.isHookEnabled()
            hookPortInput = String(UserDefaultsProviderSettingsRepository.shared.hookPort())
            antigravityAccountsPathInput = UserDefaultsProviderSettingsRepository.shared.antigravityAccountsPath()
            antigravityFetchIntervalInput = String(Int(UserDefaultsProviderSettingsRepository.shared.antigravityFetchInterval()))
        }
    }

    private var maxSettingsHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return min(screenHeight * 0.85, 650)
    }

    // MARK: - Header & Footer

    private var header: some View {
        HStack {
            Button {
                withAnimation(.easeIn(duration: 0.15)) {
                    showSettings = false
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Settings")
                .font(.system(size: 16, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeIn(duration: 0.15)) {
                    showSettings = false
                }
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(theme.accentGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - App Theme Card

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Theme")
                .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                ThemeModeButton(
                    mode: .light,
                    isSelected: settings.themeMode == ThemeMode.light.rawValue,
                    action: { settings.themeMode = ThemeMode.light.rawValue }
                )
                ThemeModeButton(
                    mode: .dark,
                    isSelected: settings.themeMode == ThemeMode.dark.rawValue,
                    action: { settings.themeMode = ThemeMode.dark.rawValue }
                )
            }
            HStack(spacing: 8) {
                ThemeModeButton(
                    mode: .system,
                    isSelected: settings.themeMode == ThemeMode.system.rawValue,
                    action: { settings.themeMode = ThemeMode.system.rawValue }
                )
                ThemeModeButton(
                    mode: .christmas,
                    isSelected: settings.themeMode == ThemeMode.christmas.rawValue,
                    action: { settings.themeMode = ThemeMode.christmas.rawValue }
                )
            }
            HStack(spacing: 8) {
                ThemeModeButton(
                    mode: .cli,
                    isSelected: settings.themeMode == ThemeMode.cli.rawValue,
                    action: { settings.themeMode = ThemeMode.cli.rawValue }
                )
            }
        }
    }

    // MARK: - Display Mode Card

    private var displayModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quota Display")
                .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                DisplayModeButton(
                    mode: .remaining,
                    isSelected: settings.usageDisplayMode == .remaining,
                    action: { settings.usageDisplayMode = .remaining }
                )
                DisplayModeButton(
                    mode: .used,
                    isSelected: settings.usageDisplayMode == .used,
                    action: { settings.usageDisplayMode = .used }
                )
                DisplayModeButton(
                    mode: .pace,
                    isSelected: settings.usageDisplayMode == .pace,
                    action: { settings.usageDisplayMode = .pace }
                )
            }
        }
    }

    // MARK: - Providers Toggle Card

    private var providersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    providersExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Enabled Providers")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(providersExpanded ? 90 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if providersExpanded {
                VStack(spacing: 8) {
                    ForEach(monitor.allProviders, id: \.id) { provider in
                        ProviderToggleRow(provider: provider, monitor: monitor)
                    }
                }
                .padding(12)
                .background(theme.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.glassBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Antigravity Config Card

    private var antigravityConfigCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    antigravityConfigExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Antigravity Configuration")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(antigravityConfigExpanded ? 90 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if antigravityConfigExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Accounts JSON Path")
                            .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        TextField("~/.config/opencode/antigravity-accounts.json", text: $antigravityAccountsPathInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(8)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.glassBorder, lineWidth: 1)
                            )
                            .onChange(of: antigravityAccountsPathInput) { _, newValue in
                                UserDefaultsProviderSettingsRepository.shared.setAntigravityAccountsPath(newValue)
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Live Fetch Interval (seconds)")
                            .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)

                        TextField("300", text: $antigravityFetchIntervalInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(8)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.glassBorder, lineWidth: 1)
                            )
                            .onChange(of: antigravityFetchIntervalInput) { _, newValue in
                                if let interval = TimeInterval(newValue) {
                                    UserDefaultsProviderSettingsRepository.shared.setAntigravityFetchInterval(interval)
                                }
                            }
                    }
                }
                .padding(16)
                .background(theme.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.glassBorder, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - General System Cards
    private var overviewModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settings.overviewModeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Overview Mode")
                        .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text("Show all enabled providers at once")
                        .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .toggleStyle(.switch)
            .tint(theme.accentPrimary)
        }
        .padding(16)
        .background(theme.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.glassBorder, lineWidth: 1)
        )
    }

    private var launchAtLoginCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settings.launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login")
                        .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text("Start GoogleAIBar when you log in")
                        .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .toggleStyle(.switch)
            .tint(theme.accentPrimary)
        }
        .padding(16)
        .background(theme.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.glassBorder, lineWidth: 1)
        )
    }

    private var backgroundSyncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    backgroundSyncExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Background Sync")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(backgroundSyncExpanded ? 90 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if backgroundSyncExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $settings.backgroundSyncEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Auto-Sync")
                                .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text("Fetch usage data automatically in background")
                                .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(theme.accentPrimary)

                    if settings.backgroundSyncEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sync Interval")
                                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text("\(Int(settings.backgroundSyncInterval / 60)) minutes")
                                    .font(.system(size: 11, weight: .bold, design: theme.fontDesign))
                                    .foregroundStyle(theme.accentPrimary)
                            }

                            Slider(
                                value: $settings.backgroundSyncInterval,
                                in: 60...3600,
                                step: 60
                            ) {
                                Text("Interval")
                            } minimumValueLabel: {
                                Text("1m").font(.caption2).foregroundStyle(theme.textTertiary)
                            } maximumValueLabel: {
                                Text("60m").font(.caption2).foregroundStyle(theme.textTertiary)
                            }
                            .tint(theme.accentPrimary)
                        }
                    }
                }
                .padding(16)
                .background(theme.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.glassBorder, lineWidth: 1)
                )
            }
        }
    }
    
    private var hooksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    hooksExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Hooks")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(hooksExpanded ? 90 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if hooksExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: Binding(
                        get: { self.hookEnabled },
                        set: { newValue in
                            self.hookEnabled = newValue
                            UserDefaultsProviderSettingsRepository.shared.setHookEnabled(newValue)
                            NotificationCenter.default.post(
                                name: .hookSettingsChanged,
                                object: nil,
                                userInfo: ["enabled": newValue]
                            )
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Session Hooks")
                                .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text("Monitor active Claude Code sessions")
                                .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(theme.accentPrimary)
                }
                .padding(16)
                .background(theme.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.glassBorder, lineWidth: 1)
                )
            }
        }
    }

    #if ENABLE_SPARKLE
    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    updatesExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Updates")
                        .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .textCase(.uppercase)

                    Spacer()
                    
                    if sparkleUpdater?.isUpdateAvailable == true {
                        UpdateBadge(accentColor: theme.accentPrimary)
                            .padding(.trailing, 4)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .rotationEffect(.degrees(updatesExpanded ? 90 : 0))
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if updatesExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Manual check button
                    Button {
                        sparkleUpdater?.checkForUpdates()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check for Updates")
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .medium, design: theme.fontDesign))
                        .padding(10)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Beta channel toggle
                    Toggle(isOn: $settings.receiveBetaUpdates) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Receive Beta Updates")
                                .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text("Get early access to new features")
                                .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(theme.accentPrimary)
                }
                .padding(16)
                .background(theme.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.glassBorder, lineWidth: 1)
                )
            }
        }
    }
    #endif

    private var logsCard: some View {
        Button {
            let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/ClaudeBar/ClaudeBar.log")
            if FileManager.default.fileExists(atPath: logURL.path) {
                NSWorkspace.shared.open(logURL)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(theme.textSecondary)
                    Text("Open Logs")
                        .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }

                Text("Opens GoogleAIBar.log in TextEdit")
                    .font(.system(size: 9, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(12)
            .background(theme.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        HStack {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

            Text("GoogleAIBar v\(version) (\(build))")
                .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            Spacer()

            Link("GitHub", destination: URL(string: "https://github.com/npdkdev/GoogleAiBar")!)
                .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.accentPrimary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Subcomponents

private struct ProviderToggleRow: View {
    @Bindable var provider: any AIProvider
    let monitor: QuotaMonitor
    @Environment(\.appTheme) private var theme

    var body: some View {
        Toggle(isOn: Binding(
            get: { provider.isEnabled },
            set: { newValue in
                provider.isEnabled = newValue
                
                // If we're turning it off, refresh the provider's data so it updates UI
                if !newValue {
                    monitor.handleProviderDisabled(provider.id)
                } else {
                    // Fetch data immediately when turned on
                    Task {
                        try? await provider.refresh()
                    }
                }
            }
        )) {
            HStack(spacing: 8) {
                ProviderIconView(providerId: provider.id, size: 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text(provider.name)
                        .font(.system(size: 13, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Probe: \(provider.cliCommand)")
                        .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(theme.accentPrimary)
    }
}

private struct ThemeModeButton: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme
    @State private var isHovering = false

    private var iconBackgroundGradient: LinearGradient {
        switch mode {
        case .light: return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dark: return LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .system: return LinearGradient(colors: [.gray, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .christmas: return ChristmasTheme().accentGradient
        case .cli: return LinearGradient(colors: [CLITheme().accentPrimary], startPoint: .top, endPoint: .bottom)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(iconBackgroundGradient)
                        .frame(width: 28, height: 28)

                    Image(systemName: mode.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mode == .cli ? Color.black : .white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.displayName)
                        .font(.system(size: 11, weight: .medium, design: mode == .cli ? .monospaced : theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.statusHealthy)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: mode == .cli ? 6 : 10)
                    .fill(isSelected ? theme.accentPrimary.opacity(0.15) : (isHovering ? theme.hoverOverlay : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: mode == .cli ? 6 : 10)
                            .stroke(isSelected ? theme.accentPrimary : theme.glassBorder.opacity(0.5), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct DisplayModeButton: View {
    let mode: UsageDisplayMode
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.appTheme) private var theme
    @State private var isHovering = false

    private var iconName: String {
        switch mode {
        case .remaining: return "arrow.down.to.line.alt"
        case .used: return "arrow.up.to.line.alt"
        case .pace: return "speedometer"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .bold))

                Text(mode.displayLabel)
                    .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(buttonBackground)
            .foregroundStyle(isSelected ? theme.accentPrimary : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? theme.accentPrimary.opacity(0.2) : (isHovering ? theme.hoverOverlay : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.accentPrimary.opacity(0.5) : theme.glassBorder, lineWidth: 1)
            )
    }
}
