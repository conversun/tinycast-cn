import Foundation

/// The consented, cacheless exchange-rate fetcher. See docs/features/calculator.md#consent.
@MainActor
@Observable
final class CurrencyRateStore {
    /// Frankfurter: no key, no quota, and the same feed `CurrencyData.generated.swift` comes from.
    static let provider = "Frankfurter"
    static let providerURL = URL(string: "https://frankfurter.dev")!
    private nonisolated static let endpoint = URL(
        string: "https://api.frankfurter.dev/v2/rates?base=USD")!
    /// Daily, measured from the persisted snapshot, so relaunching never re-fetches a fresh one.
    static let refreshInterval: TimeInterval = 24 * 3600
    /// Shorter retry, so a machine offline at launch picks rates up soon after it reconnects.
    private static let retryInterval: TimeInterval = 15 * 60

    /// Consent. Deliberately not in `AppSettings`, so no import can grant network access.
    private(set) var isEnabled: Bool

    /// The newest snapshot, nil when none has landed and always nil without consent.
    private(set) var rates: CurrencyRates?

    private static let consentKey = "currencyRatesEnabled"
    private let defaults = UserDefaults.standard
    private let fileURL: URL
    @ObservationIgnored private var pump: Task<Void, Never>?

    init() {
        // Absent reads as false, which is the only safe default for a network feature.
        isEnabled = defaults.bool(forKey: Self.consentKey)
        fileURL = AppPaths.caches().appendingPathComponent("currency-rates.json")

        // Guard 1 — a disabled feature doesn't even read back a snapshot left on disk.
        guard isEnabled, let data = try? Data(contentsOf: fileURL) else { return }
        rates = try? JSONDecoder().decode(CurrencyRates.self, from: data)
    }

    /// Guard 2, the read path: without consent the engine gets `.off`, so there is no card.
    var source: CurrencySource { isEnabled ? .on(rates) : .off }

    /// Guard 3 — no consent, no loop, so `AppCore.start()` can call this unconditionally.
    func start() {
        guard isEnabled else { return }
        // Replace rather than bail: an exited loop leaves a non-nil task that would block restart.
        pump?.cancel()
        pump = Task { [weak self] in
            while !Task.isCancelled, let self, self.isEnabled {
                // Clamped, so a future-stamped snapshot can't park the loop past one interval.
                let age = max(0, self.rates.map { Date().timeIntervalSince($0.fetchedAt) } ?? .infinity)
                guard age >= Self.refreshInterval else {
                    try? await Task.sleep(for: .seconds(Self.refreshInterval - age))
                    continue
                }
                let ok = await self.fetchAndStore()
                try? await Task.sleep(for: .seconds(ok ? Self.refreshInterval : Self.retryInterval))
            }
        }
    }

    /// The toggle's only entry point; disabling also drops the snapshot and deletes the cache.
    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.consentKey)
        if enabled {
            start()
        } else {
            pump?.cancel()
            pump = nil
            rates = nil
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// "Update Now". Returns whether a table landed, so the pane can report a failed fetch.
    func refreshNow() async -> Bool {
        guard isEnabled else { return false }
        return await fetchAndStore()
    }

    private func fetchAndStore() async -> Bool {
        // Guard 4, the network boundary: the pump may have slept through a revocation.
        guard isEnabled, let fetched = try? await Self.fetch() else { return false }
        // Re-check after the await: consent can be withdrawn while the request is in flight.
        guard isEnabled else { return false }
        rates = fetched
        if let data = try? JSONEncoder().encode(fetched) {
            try? data.write(to: fileURL, options: .atomic)
        }
        return true
    }

    /// Cacheless, never `URLSession.shared`, so revoking consent leaves no second on-disk copy.
    private nonisolated static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    /// Off-main via `URLSession`; only the plain-value `CurrencyRates` crosses back.
    private nonisolated static func fetch() async throws -> CurrencyRates {
        let request = URLRequest(url: endpoint, timeoutInterval: 20)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Frankfurter v2 answers with one flat row per pair rather than a keyed table.
        let rows = try JSONDecoder().decode([RateRow].self, from: data)
        guard let base = rows.first?.base else { throw URLError(.cannotParseResponse) }
        var rates: [String: Double] = [:]
        rates.reserveCapacity(rows.count + 1)
        for row in rows where row.rate > 0 && row.rate.isFinite && row.base == base {
            rates[row.quote] = row.rate
        }
        guard !rates.isEmpty else { throw URLError(.cannotParseResponse) }
        rates[base] = 1

        return CurrencyRates(base: base, rates: rates, fetchedAt: Date())
    }

    private struct RateRow: Decodable {
        let base: String
        let quote: String
        let rate: Double
    }
}
