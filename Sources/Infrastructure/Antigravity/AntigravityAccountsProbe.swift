import Foundation
import Domain

/// Probe that reads quota data directly from the Antigravity accounts JSON file
public actor AntigravityAccountsProbe: UsageProbe {
    private let settingsRepository: any AntigravitySettingsRepository
    private let networkClient: any NetworkClient
    
    public init(
        settingsRepository: any AntigravitySettingsRepository,
        networkClient: any NetworkClient = URLSession.shared
    ) {
        self.settingsRepository = settingsRepository
        self.networkClient = networkClient
    }
    
    public func isAvailable() async -> Bool {
        let url = try? getAccountsFileURL()
        return url != nil && FileManager.default.fileExists(atPath: url!.path)
    }
    
    public func probe() async throws -> UsageSnapshot {
        guard let url = try? getAccountsFileURL() else {
            throw ProbeError.executionFailed("Could not determine accounts file path")
        }
        
        AppLog.probes.debug("Antigravity: Reading accounts from \(url.path)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProbeError.executionFailed("Accounts file not found at \(url.path)")
        }
        
        let data = try Data(contentsOf: url)
        
        let response: AccountsResponse
        do {
            let decoder = JSONDecoder()
            response = try decoder.decode(AccountsResponse.self, from: data)
        } catch {
            AppLog.probes.error("Antigravity parse failed: Invalid JSON - \(error.localizedDescription)")
            throw ProbeError.parseFailed("Invalid JSON: \(error.localizedDescription)")
        }
        
        let interval = settingsRepository.antigravityFetchInterval()
        return try await parseAndMixAccounts(response, fetchInterval: interval)
    }
    
    private func parseAndMixAccounts(_ response: AccountsResponse, fetchInterval: TimeInterval) async throws -> UsageSnapshot {
        var allQuotas: [UsageQuota] = []
        let enabledAccounts = response.accounts.filter { $0.enabled ?? true }
        
        for account in enabledAccounts {
            let email = account.email ?? "Unknown Account"
            var cached = account.cachedQuota ?? [:]
            
            let lastUpdated = account.cachedQuotaUpdatedAt.flatMap { Date(timeIntervalSince1970: Double($0) / 1000.0) } ?? Date.distantPast
            
            if abs(Date().timeIntervalSince(lastUpdated)) > fetchInterval {
                if let refreshToken = account.refreshToken {
                    do {
                        let liveData = try await fetchLiveData(refreshToken: refreshToken)
                        for (k, v) in liveData {
                            cached[k] = v
                        }
                    } catch {
                        AppLog.probes.error("Failed to fetch live data for \(email): \(error)")
                    }
                }
            }
            
            for (modelKey, quotaInfo) in cached {
                let mappedName = mapModelName(modelKey)
                let percentRemaining = (quotaInfo.remainingFraction ?? 0.0) * 100
                let resetsAt = quotaInfo.resetTime.flatMap { parseResetTime($0) }
                
                let quota = UsageQuota(
                    percentRemaining: percentRemaining,
                    quotaType: .modelSpecific(mappedName),
                    providerId: "antigravity",
                    resetsAt: resetsAt,
                    resetText: nil,
                    accountEmail: email
                )
                allQuotas.append(quota)
            }
        }
        
        guard !allQuotas.isEmpty else {
            throw ProbeError.parseFailed("No valid quotas found in accounts file")
        }
        
        return UsageSnapshot(
            providerId: "antigravity",
            quotas: allQuotas,
            capturedAt: Date()
        )
    }
    
    private func fetchLiveData(refreshToken: String) async throws -> [String: CachedQuotaInfo] {
        guard let tokenUrl = URL(string: "https://oauth2.googleapis.com/token") else { throw ProbeError.executionFailed("Bad URL") }
        var tokenReq = URLRequest(url: tokenUrl)
        tokenReq.httpMethod = "POST"
        tokenReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let actualClientId = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
        let actualClientSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] ?? ""
        
        guard !actualClientId.isEmpty else {
            AppLog.probes.warning("GOOGLE_CLIENT_ID not found, cannot refresh token for live data")
            return [:]
        }
        
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(actualClientId)&client_secret=\(actualClientSecret)"
        tokenReq.httpBody = body.data(using: .utf8)
        
        let (tokenData, _) = try await networkClient.request(tokenReq)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: tokenData)
        guard let accessToken = tokenResponse.access_token else { return [:] }
        
        guard let fetchUrl = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels") else { return [:] }
        var fetchReq = URLRequest(url: fetchUrl)
        fetchReq.httpMethod = "POST"
        fetchReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        fetchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        fetchReq.httpBody = "{}".data(using: .utf8)
        
        let (modelsData, _) = try await networkClient.request(fetchReq)
        let modelsResp = try JSONDecoder().decode(FetchModelsResponse.self, from: modelsData)
        
        var liveData: [String: CachedQuotaInfo] = [:]
        for (modelName, info) in modelsResp.models ?? [:] {
            let group: String?
            let lower = modelName.lowercased()
            if lower.contains("claude") { group = "claude" }
            else if lower.contains("flash") { group = "gemini-flash" }
            else if lower.contains("gemini-3") || lower.contains("gemini-pro") { group = "gemini-pro" }
            else { group = nil }
            
            if let group = group, let qInfo = info.quotaInfo {
                liveData[group] = CachedQuotaInfo(
                    remainingFraction: qInfo.remainingFraction,
                    resetTime: qInfo.resetTime,
                    modelCount: nil
                )
            }
        }
        
        return liveData
    }
    
    private func getAccountsFileURL() throws -> URL {
        let customPath = settingsRepository.antigravityAccountsPath()
        if !customPath.isEmpty {
            return URL(fileURLWithPath: customPath)
        }
        
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
            return URL(fileURLWithPath: xdgConfigHome).appendingPathComponent("opencode/antigravity-accounts.json")
        }
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".config/opencode/antigravity-accounts.json")
    }
    
    private func parseResetTime(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }
    
    private func mapModelName(_ key: String) -> String {
        switch key.lowercased() {
        case "gemini-pro": return "Gemini 3.1 Pro"
        case "gemini-flash": return "Gemini 3 Flash"
        case "claude": return "Claude 3.5 Sonnet"
        default: return key.capitalized
        }
    }
}

// MARK: - Models

private struct AccountsResponse: Decodable {
    let version: Int?
    let accounts: [Account]
}

private struct Account: Decodable {
    let email: String?
    let refreshToken: String?
    let enabled: Bool?
    let cachedQuota: [String: CachedQuotaInfo]?
    let cachedQuotaUpdatedAt: Int64?
}

private struct CachedQuotaInfo: Decodable {
    let remainingFraction: Double?
    let resetTime: String?
    let modelCount: Int?
}

private struct TokenResponse: Decodable {
    let access_token: String?
}

private struct FetchModelsResponse: Decodable {
    let models: [String: ModelInfo]?
}

private struct ModelInfo: Decodable {
    let quotaInfo: LiveQuotaInfo?
}

private struct LiveQuotaInfo: Decodable {
    let remainingFraction: Double?
    let resetTime: String?
}
