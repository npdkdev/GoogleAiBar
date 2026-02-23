import Foundation
import Domain

/// A probe that tries a primary probe first, falling back to a secondary probe if the primary is unavailable or fails.
public struct FallbackUsageProbe: UsageProbe {
    private let primary: any UsageProbe
    private let fallback: any UsageProbe

    public init(primary: any UsageProbe, fallback: any UsageProbe) {
        self.primary = primary
        self.fallback = fallback
    }

    public func isAvailable() async -> Bool {
        await primary.isAvailable() || fallback.isAvailable()
    }

    public func probe() async throws -> UsageSnapshot {
        if await primary.isAvailable() {
            do {
                return try await primary.probe()
            } catch {
                AppLog.probes.warning("Primary probe failed, trying fallback: \(error.localizedDescription)")
            }
        }
        return try await fallback.probe()
    }
}
