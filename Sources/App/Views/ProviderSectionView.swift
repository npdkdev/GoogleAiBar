import SwiftUI
import Domain

struct ProviderSectionView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(snapshot.overallStatus.displayColor)
                    .frame(width: 8, height: 8)

                Text(providerDisplayName)
                    .font(.headline)

                Spacer()

                if let email = snapshot.accountEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if hasMultipleAccounts {
                multiAccountView
            } else {
                singleAccountQuotaGrid(quotas: snapshot.quotas)
            }

            // Age indicator
            HStack {
                Text("Updated \(snapshot.ageDescription)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if snapshot.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
    }

    private var hasMultipleAccounts: Bool {
        let emails = Set(snapshot.quotas.compactMap { $0.accountEmail })
        return emails.count > 1
    }

    private var accountGroups: [(email: String, quotas: [UsageQuota])] {
        var groups: [(email: String, quotas: [UsageQuota])] = []
        var seen: [String: Int] = [:]
        for quota in snapshot.quotas {
            let key = quota.accountEmail ?? ""
            if let idx = seen[key] {
                groups[idx].quotas.append(quota)
            } else {
                seen[key] = groups.count
                groups.append((email: quota.accountEmail ?? "", quotas: [quota]))
            }
        }
        return groups
    }

    @ViewBuilder
    private var multiAccountView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(accountGroups, id: \.email) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    singleAccountQuotaGrid(quotas: group.quotas)
                }
            }
        }
    }

    @ViewBuilder
    private func singleAccountQuotaGrid(quotas: [UsageQuota]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            ForEach(quotas, id: \.quotaType) { quota in
                QuotaCardView(quota: quota)
            }
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
    }

    private var providerDisplayName: String {
        ProviderVisualIdentityLookup.name(for: snapshot.providerId)
    }
}
