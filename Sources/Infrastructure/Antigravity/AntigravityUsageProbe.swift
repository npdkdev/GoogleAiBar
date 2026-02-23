import Foundation
import Domain

/// Dummy probe to act as a fallback. 
/// We keep the file signature for older projects that reference it.
public struct AntigravityUsageProbe: UsageProbe {
    public init() {}
    public func isAvailable() async -> Bool { return false }
    public func probe() async throws -> UsageSnapshot { throw ProbeError.executionFailed("Legacy probe disabled") }
}
