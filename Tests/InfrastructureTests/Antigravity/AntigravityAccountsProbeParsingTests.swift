import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct AntigravityAccountsProbeParsingTests {

    static let sampleAccountsJSON = """
    {
      "version": 4,
      "accounts": [
        {
          "email": "user@gmail.com",
          "refreshToken": "some-token",
          "enabled": true,
          "cachedQuota": {
            "gemini-pro": { "remainingFraction": 1.0, "resetTime": "2026-02-23T10:41:20Z" },
            "claude": { "remainingFraction": 0.2, "resetTime": "2026-02-27T07:02:18Z" }
          },
          "cachedQuotaUpdatedAt": 1771826227823
        }
      ]
    }
    """

    static let multiAccountJSON = """
    {
      "version": 4,
      "accounts": [
        {
          "email": "alice@gmail.com",
          "refreshToken": "token-alice",
          "enabled": true,
          "cachedQuota": {
            "claude": { "remainingFraction": 0.8, "resetTime": "2026-02-27T07:02:18Z" }
          },
          "cachedQuotaUpdatedAt": 1771826227823
        },
        {
          "email": "bob@gmail.com",
          "refreshToken": "token-bob",
          "enabled": true,
          "cachedQuota": {
            "claude": { "remainingFraction": 0.3, "resetTime": "2026-02-28T07:02:18Z" }
          },
          "cachedQuotaUpdatedAt": 1771826227823
        }
      ]
    }
    """

    static let disabledAccountJSON = """
    {
      "version": 4,
      "accounts": [
        {
          "email": "active@gmail.com",
          "enabled": true,
          "cachedQuota": {
            "claude": { "remainingFraction": 0.9, "resetTime": "2026-02-27T07:02:18Z" }
          }
        },
        {
          "email": "disabled@gmail.com",
          "enabled": false,
          "cachedQuota": {
            "claude": { "remainingFraction": 0.1, "resetTime": "2026-02-27T07:02:18Z" }
          }
        }
      ]
    }
    """

    static let noCachedQuotaJSON = """
    {
      "version": 4,
      "accounts": [
        {
          "email": "user@gmail.com",
          "enabled": true
        }
      ]
    }
    """

    static let allDisabledJSON = """
    {
      "version": 4,
      "accounts": [
        {
          "email": "user@gmail.com",
          "enabled": false,
          "cachedQuota": {
            "claude": { "remainingFraction": 0.5 }
          }
        }
      ]
    }
    """

    // MARK: - Basic Parsing

    @Test
    func `parses single account with two models`() throws {
        let data = Data(Self.sampleAccountsJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        #expect(snapshot.quotas.count == 2)
        #expect(snapshot.providerId == "antigravity")
    }

    @Test
    func `maps remainingFraction to percentRemaining`() throws {
        let data = Data(Self.sampleAccountsJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        let geminiQuota = snapshot.quotas.first { $0.quotaType == .modelSpecific("gemini-pro") }
        let claudeQuota = snapshot.quotas.first { $0.quotaType == .modelSpecific("claude") }

        #expect(geminiQuota?.percentRemaining == 100.0)
        #expect(claudeQuota?.percentRemaining == 20.0)
    }

    @Test
    func `sets accountEmail on each quota`() throws {
        let data = Data(Self.sampleAccountsJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        #expect(snapshot.quotas.allSatisfy { $0.accountEmail == "user@gmail.com" })
    }

    @Test
    func `parses resetTime as ISO8601 Date`() throws {
        let data = Data(Self.sampleAccountsJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        let geminiQuota = snapshot.quotas.first { $0.quotaType == .modelSpecific("gemini-pro") }
        let expectedDate = ISO8601DateFormatter().date(from: "2026-02-23T10:41:20Z")
        #expect(geminiQuota?.resetsAt == expectedDate)
    }

    @Test
    func `creates modelSpecific quotaType from model name key`() throws {
        let data = Data(Self.sampleAccountsJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        let modelNames = snapshot.quotas.compactMap { $0.quotaType.modelName }
        #expect(modelNames.contains("claude"))
        #expect(modelNames.contains("gemini-pro"))
    }

    @Test
    func `sets snapshot accountEmail for single account`() throws {
        let data = Data(Self.sampleAccountsJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        #expect(snapshot.accountEmail == "user@gmail.com")
    }

    @Test
    func `snapshot accountEmail is nil for multiple accounts`() throws {
        let data = Data(Self.multiAccountJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        #expect(snapshot.accountEmail == nil)
    }

    // MARK: - Multi-Account

    @Test
    func `parses two enabled accounts producing separate quotas`() throws {
        let data = Data(Self.multiAccountJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        #expect(snapshot.quotas.count == 2)

        let aliceQuota = snapshot.quotas.first { $0.accountEmail == "alice@gmail.com" }
        let bobQuota = snapshot.quotas.first { $0.accountEmail == "bob@gmail.com" }

        #expect(aliceQuota?.percentRemaining == 80.0)
        #expect(bobQuota?.percentRemaining == 30.0)
    }

    @Test
    func `each quota carries correct accountEmail from its account`() throws {
        let data = Data(Self.multiAccountJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        let emails = Set(snapshot.quotas.compactMap { $0.accountEmail })
        #expect(emails == ["alice@gmail.com", "bob@gmail.com"])
    }

    // MARK: - Disabled Accounts

    @Test
    func `skips disabled accounts`() throws {
        let data = Data(Self.disabledAccountJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.accountEmail == "active@gmail.com")
    }

    @Test
    func `throws when all accounts are disabled`() throws {
        let data = Data(Self.allDisabledJSON.utf8)

        #expect(throws: ProbeError.self) {
            try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")
        }
    }

    // MARK: - Missing Quota Data

    @Test
    func `throws when enabled account has no cachedQuota`() throws {
        let data = Data(Self.noCachedQuotaJSON.utf8)

        #expect(throws: ProbeError.self) {
            try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")
        }
    }

    @Test
    func `throws for invalid JSON`() throws {
        let data = Data("not json".utf8)

        #expect(throws: ProbeError.self) {
            try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")
        }
    }

    // MARK: - capturedAt from timestamp

    @Test
    func `sets capturedAt from cachedQuotaUpdatedAt milliseconds`() throws {
        let data = Data(Self.sampleAccountsJSON.utf8)
        let snapshot = try AntigravityAccountsProbe.parseAccountsFile(data, providerId: "antigravity")

        let expectedDate = Date(timeIntervalSince1970: TimeInterval(1771826227823) / 1000.0)
        #expect(abs(snapshot.capturedAt.timeIntervalSince(expectedDate)) < 1.0)
    }

    // MARK: - isAvailable

    @Test
    func `isAvailable returns false when file does not exist`() async {
        let probe = AntigravityAccountsProbe(fileURL: URL(fileURLWithPath: "/nonexistent/path/file.json"))
        #expect(await probe.isAvailable() == false)
    }

    @Test
    func `isAvailable returns true when file exists`() async throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-antigravity-accounts.json")
        try Data(Self.sampleAccountsJSON.utf8).write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let probe = AntigravityAccountsProbe(fileURL: tmpURL)
        #expect(await probe.isAvailable() == true)
    }

    // MARK: - probe() integration

    @Test
    func `probe returns snapshot from valid file`() async throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-antigravity-accounts-probe.json")
        try Data(Self.sampleAccountsJSON.utf8).write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let probe = AntigravityAccountsProbe(fileURL: tmpURL)
        let snapshot = try await probe.probe()

        #expect(snapshot.quotas.count == 2)
        #expect(snapshot.providerId == "antigravity")
    }

    @Test
    func `probe throws cliNotFound when file is missing`() async throws {
        let probe = AntigravityAccountsProbe(fileURL: URL(fileURLWithPath: "/nonexistent/path/file.json"))

        await #expect(throws: ProbeError.self) {
            try await probe.probe()
        }
    }
}
