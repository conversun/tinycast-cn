import SwiftUI

/// The catch-all pane. Home to currency conversion — the one feature in Tinycast that reaches the
/// network, which is why it ships off and needs an explicit yes before it can be switched on.
struct MiscellaneousSettingsView: View {
    @ObservedObject private var currencyRates = AppCore.shared.currencyRates
    @State private var askingConsent = false
    @State private var refreshing = false
    @State private var refreshFailed = false

    var body: some View {
        SettingsPane(
            title: "Miscellaneous",
            subtitle: "Options that don't belong to a single feature."
        ) {
            SettingsCard(header: "Calculator") {
                SettingsRow(
                    title: "Currency Conversion",
                    subtitle: conversionStatus,
                    systemImage: "dollarsign.arrow.circlepath",
                    tint: .green,
                    statusDot: currencyRates.isEnabled ? .green : nil
                ) {
                    // Deliberately not bound straight to the setting: flipping it on only opens the
                    // consent sheet, so the switch springs back until the user actually accepts.
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { currencyRates.isEnabled },
                            set: { wantsOn in
                                if wantsOn {
                                    askingConsent = true
                                } else {
                                    currencyRates.setEnabled(false)
                                }
                            })
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }

                if currencyRates.isEnabled {
                    SettingsDivider()
                    SettingsRow(
                        title: "Exchange Rates",
                        subtitle: ratesStatus,
                        systemImage: "clock.arrow.circlepath",
                        tint: .gray
                    ) {
                        Button("Update Now") {
                            refreshing = true
                            Task {
                                let landed = await currencyRates.refreshNow()
                                refreshFailed = !landed
                                refreshing = false
                            }
                        }
                        .disabled(refreshing)
                    }
                }
            }
        }
        .sheet(isPresented: $askingConsent) {
            CurrencyConsentSheet(
                onCancel: { askingConsent = false },
                onAccept: {
                    askingConsent = false
                    currencyRates.setEnabled(true)
                })
        }
    }

    /// Carries the off-state promise that used to need its own callout: nothing is contacted until
    /// the switch is on.
    private var conversionStatus: String {
        let examples = "Convert inline — \"100 dollars to yen\", \"€20 to GBP\".".localizedUI
        guard !currencyRates.isEnabled else { return examples }
        return String(format: "%@ Off — no service is contacted.".localizedUI, examples)
    }

    private var ratesStatus: String {
        if refreshing { return "Updating…".localizedUI }
        if refreshFailed {
            return String(
                format: "Couldn't reach %@. Try again.".localizedUI, CurrencyRateStore.provider)
        }
        guard let fetched = currencyRates.rates?.fetchedAt else {
            return String(
                format: "%@ · not downloaded yet.".localizedUI, CurrencyRateStore.provider)
        }
        let stamp = fetched.formatted(date: .abbreviated, time: .shortened)
        return String(
            format: "%@ · updated %@. Refreshes daily.".localizedUI, CurrencyRateStore.provider,
            stamp)
    }
}

/// The consent step. Three facts are the ones that actually decide the answer — who is contacted, how
/// often, and that nothing personal goes with it — plus the provider link so the claim is checkable.
private struct CurrencyConsentSheet: View {
    let onCancel: () -> Void
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            HStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "network")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.green)
                Text("Turn on currency conversion?")
                    .font(.headline)
            }

            Text(
                String(
                    format: ("Tinycast downloads exchange rates from %@ once a day and keeps a "
                        + "copy on your Mac. No account, no identifiers, nothing you type. "
                        + "Turning it off deletes the cached rates.").localizedUI,
                    CurrencyRateStore.provider)
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.lg) {
                Link(destination: CurrencyRateStore.providerURL) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(CurrencyRateStore.providerURL.host() ?? "Provider")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.callout)
                }
                Spacer()
                Button("Not Now", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Enable", action: onAccept)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xxl)
        .frame(width: 420)
    }
}
